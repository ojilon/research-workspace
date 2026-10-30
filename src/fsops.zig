//! The small file operations revise needs, over Zig 0.17's `std.Io`. Every
//! one is called from the UI thread and only touches files the app itself
//! would: reading sources and caches, and listing a folder.
const std = @import("std");
const Io = std.Io;

pub const max_read = 64 * 1024 * 1024;

pub const FileInfo = struct {
    size: u64 = 0,
    /// Nanoseconds since the epoch, as Python's `st_mtime_ns`.
    mtime: i64 = 0,
};

pub fn readFile(allocator: std.mem.Allocator, io: Io, path: []const u8) ![]u8 {
    return Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_read));
}

/// Null when the file is not there (or is not a file): a missing cache is a
/// normal state, not an error.
pub fn statFile(io: Io, path: []const u8) ?FileInfo {
    const st = Io.Dir.cwd().statFile(io, path, .{}) catch return null;
    return .{
        .size = st.size,
        .mtime = @intCast(st.mtime.nanoseconds),
    };
}

pub fn exists(io: Io, path: []const u8) bool {
    return statFile(io, path) != null;
}

pub fn writeFile(io: Io, path: []const u8, bytes: []const u8) !void {
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes });
}

/// `mkdir -p`.
pub fn makePath(io: Io, path: []const u8) !void {
    Io.Dir.cwd().createDirPath(io, path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

pub const Entry = struct {
    name: []u8,
    is_dir: bool,
    /// Order in the tree: folders first, then names.
    pub fn lessThan(_: void, a: Entry, b: Entry) bool {
        if (a.is_dir != b.is_dir) return a.is_dir;
        return std.mem.lessThan(u8, a.name, b.name);
    }
};

pub const Listing = struct {
    arena: std.heap.ArenaAllocator,
    entries: []const Entry = &.{},

    pub fn deinit(self: *Listing, gpa: std.mem.Allocator) void {
        self.arena.deinit();
        gpa.destroy(self);
    }
};

/// A folder's entries: sub-folders first, then files revise can open, then
/// other files (so the tree can show them greyed out). Hidden names and the
/// app's own `.revise` are left out.
pub fn listDir(gpa: std.mem.Allocator, io: Io, path: []const u8) !*Listing {
    const self = try gpa.create(Listing);
    self.* = .{ .arena = std.heap.ArenaAllocator.init(gpa) };
    errdefer {
        self.arena.deinit();
        gpa.destroy(self);
    }
    const allocator = self.arena.allocator();
    var dir = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.NotDir, error.AccessDenied => return self,
        else => return err,
    };
    defer dir.close(io);
    var entries: std.ArrayList(Entry) = .empty;
    var it = dir.iterate();
    while (it.next(io) catch null) |e| {
        if (e.kind == .sym_link) continue;
        if (e.name.len == 0 or e.name[0] == '.') continue;
        if (e.name[0] == '~' or e.name[0] == '$') continue;
        const is_dir = e.kind == .directory;
        entries.append(allocator, .{
            .name = try allocator.dupe(u8, e.name),
            .is_dir = is_dir,
        }) catch break;
    }
    std.mem.sort(Entry, entries.items, {}, Entry.lessThan);
    self.entries = try entries.toOwnedSlice(allocator);
    return self;
}

test "listing a temporary folder" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const io = std.testing.io;
    const base = "/tmp/revise-fsops-test";
    Io.Dir.cwd().deleteTree(io, base) catch {};
    try makePath(io, base);
    defer Io.Dir.cwd().deleteTree(io, base) catch {};
    try makePath(io, base ++ "/sub");
    try writeFile(io, base ++ "/a.md", "hello");
    try writeFile(io, base ++ "/.hidden", "x");
    const list = try listDir(allocator, io, base);
    defer list.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), list.entries.len);
    try std.testing.expectEqualStrings("sub", list.entries[0].name);
    try std.testing.expect(list.entries[0].is_dir);
    try std.testing.expectEqualStrings("a.md", list.entries[1].name);
    try std.testing.expect(!list.entries[1].is_dir);

    const info = statFile(io, base ++ "/a.md").?;
    try std.testing.expectEqual(@as(u64, 5), info.size);
    try std.testing.expect(info.mtime > 0);
    try std.testing.expect(!exists(io, base ++ "/missing.md"));

    const bytes = try readFile(allocator, io, base ++ "/a.md");
    try std.testing.expectEqualStrings("hello", bytes);
}
