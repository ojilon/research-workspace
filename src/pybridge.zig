//! Runs the Python tools without blocking the UI.
//!
//! A request starts a thread that calls `std.process.run` with an `Io` of its
//! own and collects stdout/stderr; the view polls `Runner.take` once a frame
//! while `Runner.busy` is true. Python is found in this order: the
//! `REVISE_PYTHON` environment variable, the workspace's `.venv` (Windows:
//! `.venv\Scripts\python.exe`), then `python3`/`python`/`py` on PATH.
const std = @import("std");
const Io = std.Io;
const builtin = @import("builtin");
const paths = @import("paths.zig");
const fsops = @import("fsops.zig");

const is_windows = builtin.os.tag == .windows;

pub const Tool = enum {
    extract,
    save_docx,
    save_text,
    new_file,
    db,

    pub fn fileName(t: Tool) []const u8 {
        return switch (t) {
            .extract => "extract.py",
            .save_docx => "save_docx.py",
            .save_text => "save_text.py",
            .new_file => "new_file.py",
            .db => "db.py",
        };
    }
};

/// One run of one tool. Its memory belongs to the app until `deinit`.
pub const Job = struct {
    gpa: std.mem.Allocator,
    argv: []const []u8,
    finished: std.atomic.Value(bool) = .init(false),
    out: []u8 = &.{},
    err_out: []u8 = &.{},
    spawn_error: ?anyerror = null,
    exit_ok: bool = false,

    pub fn output(job: *Job) []const u8 {
        return job.out;
    }

    pub fn stderrText(job: *Job) []const u8 {
        return job.err_out;
    }

    /// The tool's `{"error":"..."}`, when it failed to do its job.
    pub fn jsonError(job: *Job) ?[]const u8 {
        const Text = struct { @"error": ?[]const u8 = null };
        const parsed = std.json.parseFromSlice(Text, job.gpa, job.out, .{
            .ignore_unknown_fields = true,
        }) catch return null;
        defer parsed.deinit();
        return parsed.value.@"error";
    }

    pub fn deinit(job: *Job) void {
        const gpa = job.gpa;
        for (job.argv) |a| gpa.free(a);
        gpa.free(job.argv);
        if (job.out.len > 0) gpa.free(job.out);
        if (job.err_out.len > 0) gpa.free(job.err_out);
        gpa.destroy(job);
    }
};

fn work(job: *Job) void {
    var threaded: Io.Threaded = .init(job.gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const result = std.process.run(job.gpa, io, .{
        .argv = job.argv,
        .stdout_limit = .limited(32 * 1024 * 1024),
        .stderr_limit = .limited(1 << 20),
    }) catch |err| {
        job.spawn_error = err;
        job.finished.store(true, .release);
        return;
    };
    // Everything is written before the flag: `take` reads it with acquire.
    job.out = result.stdout;
    job.err_out = result.stderr;
    job.exit_ok = result.term.success();
    job.finished.store(true, .release);
}

pub const Runner = struct {
    gpa: std.mem.Allocator,
    io: Io,
    python: []u8,
    tools: []u8,
    pending: ?*Job = null,

    pub fn init(gpa: std.mem.Allocator, io: Io, env: *const std.process.Environ.Map) !Runner {
        return .{
            .gpa = gpa,
            .io = io,
            .python = try findPython(gpa, io, env),
            .tools = try findToolsDir(gpa, io, env),
        };
    }

    pub fn deinit(self: *Runner) void {
        if (self.pending) |job| {
            // The thread still owns it; the process is ending.
            _ = job;
            self.pending = null;
        }
        self.gpa.free(self.python);
        self.gpa.free(self.tools);
    }

    pub fn busy(self: *const Runner) bool {
        return self.pending != null;
    }

    /// Runs `tool` with `args`. Refused while another run is going: the app
    /// queues its own work, one Python process at a time.
    pub fn start(self: *Runner, tool: Tool, args: []const []const u8) !void {
        if (self.pending != null) return error.Busy;
        const tool_path = try paths.join(self.gpa, &.{ self.tools, tool.fileName() });
        defer self.gpa.free(tool_path);
        const argv = try self.gpa.alloc([]u8, 2 + args.len);
        errdefer self.gpa.free(argv);
        var made: usize = 0;
        errdefer for (argv[0..made]) |a| self.gpa.free(a);
        argv[0] = try self.gpa.dupe(u8, self.python);
        made += 1;
        argv[1] = try self.gpa.dupe(u8, tool_path);
        made += 1;
        for (args, 0..) |a, i| {
            argv[2 + i] = try self.gpa.dupe(u8, a);
            made += 1;
        }
        const job = try self.gpa.create(Job);
        job.* = .{ .gpa = self.gpa, .argv = argv };
        errdefer self.gpa.destroy(job);
        const thread = std.Thread.spawn(.{}, work, .{job}) catch |err| {
            job.deinit();
            return err;
        };
        thread.detach();
        self.pending = job;
    }

    /// The finished job, if it has finished: the caller reads its output and
    /// calls `Job.deinit`. Null while it is still running, or when idle.
    pub fn take(self: *Runner) ?*Job {
        const job = self.pending orelse return null;
        if (!job.finished.load(.acquire)) return null;
        self.pending = null;
        return job;
    }
};

/// Pythons to try, best first. The workspace's own `.venv` beats PATH, so a
/// checkout behaves the same on a machine with a different system Python.
pub fn interpreterCandidates(allocator: std.mem.Allocator, root: []const u8) ![][]u8 {
    var out: std.ArrayList([]u8) = .empty;
    errdefer {
        for (out.items) |s| allocator.free(s);
        out.deinit(allocator);
    }
    const venv_paths: [2][]const u8 = if (is_windows)
        .{ ".venv\\Scripts\\python.exe", ".venv\\Scripts\\python3.exe" }
    else
        .{ ".venv/bin/python", ".venv/bin/python3" };
    for (venv_paths) |rel| {
        try out.append(allocator, try paths.join(allocator, &.{ ".", rel }));
        if (root.len > 0) try out.append(allocator, try paths.join(allocator, &.{ root, rel }));
    }
    try out.append(allocator, try allocator.dupe(u8, if (is_windows) "python" else "python3"));
    try out.append(allocator, try allocator.dupe(u8, "python"));
    if (is_windows) try out.append(allocator, try allocator.dupe(u8, "py"));
    return out.toOwnedSlice(allocator);
}

pub fn findPython(gpa: std.mem.Allocator, io: Io, env: *const std.process.Environ.Map) ![]u8 {
    if (env.get("REVISE_PYTHON")) |given| {
        if (given.len > 0) return gpa.dupe(u8, given);
    }
    const candidates = try interpreterCandidates(gpa, ".");
    defer {
        for (candidates) |c| gpa.free(c);
        gpa.free(candidates);
    }
    for (candidates) |c| {
        if (fsops.exists(io, c)) return gpa.dupe(u8, c);
    }
    // Nothing on disk: let the system resolve the bare name.
    return gpa.dupe(u8, if (is_windows) "python" else "python3");
}

/// Where the `tools/` folder is: `REVISE_TOOLS`, `./tools`, then two levels
/// above the executable (a checkout's `zig-out/bin/revise`).
pub fn findToolsDir(gpa: std.mem.Allocator, io: Io, env: *const std.process.Environ.Map) ![]u8 {
    if (env.get("REVISE_TOOLS")) |given| {
        if (given.len > 0) return gpa.dupe(u8, given);
    }
    const local = try paths.join(gpa, &.{ ".", "tools" });
    const local_tool = try paths.join(gpa, &.{ local, "extract.py" });
    defer gpa.free(local_tool);
    if (fsops.exists(io, local_tool)) return local;
    gpa.free(local);
    if (std.process.executablePathAlloc(io, gpa)) |exe| {
        defer gpa.free(exe);
        const exe_dir = std.fs.path.dirname(exe) orelse ".";
        const up = try paths.join(gpa, &.{ exe_dir, "..", "..", "tools" });
        const up_tool = try paths.join(gpa, &.{ up, "extract.py" });
        defer gpa.free(up_tool);
        if (fsops.exists(io, up_tool)) return up;
        gpa.free(up);
    } else |_| {}
    return gpa.dupe(u8, "tools");
}

// --- tests -----------------------------------------------------------------

test "candidate order puts the venv before PATH" {
    const a = std.testing.allocator;
    const candidates = try interpreterCandidates(a, "/work");
    defer {
        for (candidates) |c| a.free(c);
        a.free(candidates);
    }
    try std.testing.expectEqual(@as(usize, 6), candidates.len);
    try std.testing.expect(std.mem.indexOf(u8, candidates[0], ".venv") != null);
    try std.testing.expect(std.mem.indexOf(u8, candidates[1], "/work") != null);
    try std.testing.expectEqualStrings(if (is_windows) "python" else "python3", candidates[4]);
    try std.testing.expectEqualStrings("python", candidates[5]);
}

test "a workspace venv wins when it exists" {
    const a = std.testing.allocator;
    const io = std.testing.io;
    const base = "/tmp/revise-pybridge-test";
    Io.Dir.cwd().deleteTree(io, base) catch {};
    try fsops.makePath(io, base);
    defer Io.Dir.cwd().deleteTree(io, base) catch {};
    const venv_python = if (is_windows) base ++ "/.venv/Scripts/python.exe" else base ++ "/.venv/bin/python";
    if (std.fs.path.dirname(venv_python)) |d| try fsops.makePath(io, d);
    try fsops.writeFile(io, venv_python, "");

    var env: std.process.Environ.Map = .init(a);
    defer env.deinit();
    try env.put("REVISE_PYTHON", venv_python);
    const found = try findPython(a, io, &env);
    defer a.free(found);
    try std.testing.expectEqualStrings(venv_python, found);
}

test "tools dir is found in a checkout" {
    const a = std.testing.allocator;
    const io = std.testing.io;
    var env: std.process.Environ.Map = .init(a);
    defer env.deinit();
    const dir = try findToolsDir(a, io, &env);
    defer a.free(dir);
    try std.testing.expect(dir.len > 0);
}
