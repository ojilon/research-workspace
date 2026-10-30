//! Bottom status bar: file path, page, word count, key hints.
const ui = @import("nanoui").ui;
const theme = @import("theme.zig");

pub const StatusBar = struct {
    path: []const u8 = "",
    page: usize = 1,
    total_pages: usize = 2,
    words: usize = 0,

    pub fn view(s: *StatusBar, c: *ui.Context) void {
        const th = c.theme;
        ui.row(c, .{
            .width = .fill,
            .height = .{ .px = 26 },
            .background = th.surface,
            .border = th.border,
            .border_width = 1,
            .align_items = .center,
            .padding = .xy(10, 0),
        });
        defer ui.end(c);
        ui.textf(c, .{ .size = 11, .color = th.muted }, "{s}  ·  Page {d} / {d}  ·  {d} words", .{ s.path, s.page, s.total_pages, s.words });
        ui.spacer(c);
        ui.kbd(c, ui.keys.label("Ctrl+P"));
        ui.text(c, " Open", .{ .size = 11, .color = th.muted });
        ui.kbd(c, ui.keys.label("Ctrl+Shift+F"));
        ui.text(c, " Search all", .{ .size = 11, .color = th.muted });
        ui.kbd(c, ui.keys.label("Ctrl+S"));
        ui.text(c, " Save", .{ .size = 11, .color = th.muted });
    }
};
