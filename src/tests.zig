//! `zig build test` runs every module's tests through this file, so a new
//! module is one line here.
const std = @import("std");

test {
    _ = @import("theme.zig");
    _ = @import("statusbar.zig");
    _ = @import("tabs.zig");
    _ = @import("sidebar.zig");
    _ = @import("menu_bar.zig");
    _ = @import("overlays.zig");
    _ = @import("reader_pane.zig");
    _ = @import("editor_pane.zig");
    _ = @import("app.zig");
    std.testing.refAllDecls(@This());
    _ = @import("paths.zig");
    _ = @import("markers.zig");
    _ = @import("model.zig");
    _ = @import("fsops.zig");
    _ = @import("pybridge.zig");
}
