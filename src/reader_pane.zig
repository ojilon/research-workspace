//! Read-only, scrollable, selectable text: hardcoded multi-paragraph
//! sample, a ruler ("Page n / 2") between pages, one highlighted
//! sentence. Text selection and Copy (Ctrl+C) work via nanoui's
//! selectable style; nothing here can be edited.
const ui = @import("nanoui").ui;
const theme = @import("theme.zig");
const std = @import("std");

pub const Page = struct { paras: []const []const u8 };

pub const Reader = struct {
    pages: []const Page = &.{},
    /// When a paragraph equals this, it is rendered highlighted.
    highlight: ?[]const u8 = null,

    pub fn view(s: *Reader, c: *ui.Context) void {
        const th = c.theme;
        ui.scroll(c, .{
            .grow = 1,
            .width = .fill,
            .padding = .all(18),
            .gap = 14,
            .background = th.surface,
            .border = th.border,
            .border_width = 1,
            .selectable = true,
        });
        defer ui.end(c);
        for (s.pages, 0..) |page, pi| {
            if (pi > 0) ruler(c, pi + 1, s.pages.len);
            for (page.paras) |para| {
                if (s.highlight) |h| if (std.mem.eql(u8, para, h)) {
                    s.highlighted(para, c);
                    continue;
                };
                ui.text(c, para, .{ .wrap = true, .size = 13, .leading = 1.5, .color = th.text });
            }
        }
    }

    fn highlighted(s: *Reader, str: []const u8, c: *ui.Context) void {
        _ = s;
        const th = c.theme;
        const word = "memorise";
        const at = std.mem.indexOf(u8, str, word) orelse 0;
        const spans = [_]ui.Span{
            .{ .start = @intCast(at), .end = @intCast(at + word.len), .background = th.accent.alpha(0.35) },
        };
        ui.richText(c, str, &spans, .{ .wrap = true, .size = 13, .leading = 1.5, .color = th.text });
    }
};

/// A thin line with a page label between pages.
pub fn ruler(c: *ui.Context, page: usize, total: usize) void {
    const th = c.theme;
    ui.row(c, .{ .width = .fill, .gap = 8, .align_items = .center });
    defer ui.end(c);
    _ = c.leaf(.{ .grow = 1, .height = .{ .px = 1 }, .background = th.border }, .none, null);
    ui.textf(c, .{ .size = 11, .color = th.muted }, "Page {d} / {d}", .{ page, total });
    _ = c.leaf(.{ .grow = 1, .height = .{ .px = 1 }, .background = th.border }, .none, null);
}
