//! revise: an exam-revision reader for PDFs and Word documents.
//!
//!     revise [folder | file]
//!
//! Python (in `tools/`) does the file formats and the database; Zig draws the
//! screen and never parses a PDF, a DOCX or SQLite itself.
const std = @import("std");
const nanoui = @import("nanoui");
const app_mod = @import("app.zig");
const paths = @import("paths.zig");
const fsops = @import("fsops.zig");
const theme = @import("theme.zig");

pub fn main(init: std.process.Init) !void {
    const app = try nanoui.App.create(init, .{ .name = "revise" });
    defer app.destroy();

    const state = try app_mod.App.init(init.gpa, init.io, init.environ_map);
    defer state.deinit();

    var dir_arg: ?[]u8 = null;
    var file_arg: ?[]u8 = null;
    defer if (dir_arg) |p| init.gpa.free(p);
    defer if (file_arg) |p| init.gpa.free(p);

    {
        var it = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.arena.allocator());
        defer it.deinit();
        _ = it.next(); // the program's own name
        while (it.next()) |arg| {
            if (arg.len == 0 or arg[0] == '-') continue;
            const abs = paths.absoluteNorm(init.gpa, arg, state.cwd) catch continue;
            if (paths.kindOf(abs) != null) {
                file_arg = abs;
                // A document on its own opens the folder it sits in.
                if (dir_arg == null) dir_arg = init.gpa.dupe(u8, paths.dirname(abs)) catch null;
            } else {
                if (dir_arg) |old| init.gpa.free(old);
                dir_arg = abs;
            }
        }
    }

    if (dir_arg) |dir| state.setRoot(dir);
    state.debug_layout = init.environ_map.get("REVISE_DEBUG_LAYOUT") != null;
    state.start(file_arg);

    const win = try app.newWindow(.{
        .title = "revise",
        .width = 1180,
        .height = 780,
        .min_width = 900,
        .min_height = 560,
        .theme = theme.dark,
        .content = .{ .view = .init(state, app_mod.App.view) },
    });
    state.win = win;
    try app.run();
}
