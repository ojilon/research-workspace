//! The one-line status bar: what document is open, where in it, how many
//! words, the zoom, a message when there is one, and the key hints.
//! Items are separated by 1 px rules, as in the design.
const ui = @import("nanoui").ui;

pub const Kind = enum { plain, good, bad, busy };

pub const Info = struct {
    path: []const u8 = "",
    /// "Page 3 / 12", "¶ 4 / 210" or "Line 40 / 210".
    position: []const u8 = "",
    words: usize = 0,
    zoom: f32 = 1,
    message: []const u8 = "",
    message_kind: Kind = .plain,
};

fn statusColor(th: ui.Theme, kind: Kind) ui.Color {
    return switch (kind) {
        .plain => th.muted,
        .good => th.success,
        .bad => th.danger,
        .busy => th.accent,
    };
}

fn rule(c: *ui.Context) void {
    _ = c.leaf(.{ .width = .{ .px = 1 }, .height = .{ .px = 12 }, .background = c.theme.border }, .none, "status-rule");
}

fn item(c: *ui.Context, text: []const u8, color: ui.Color, tabular: bool) void {
    ui.text(c, text, .{ .size = 11.5, .color = color, .tabular = tabular });
}

pub fn view(c: *ui.Context, info: Info) void {
    const th = c.theme;
    ui.row(c, .{
        .width = .fill,
        .height = .{ .px = 26 },
        .padding = .xy(12, 0),
        .align_items = .center,
        .gap = 12,
        .background = th.surface,
        .border = th.border,
    });
    defer ui.end(c);

    if (info.path.len > 0) {
        _ = c.open(.{ .width = .{ .px = 300 }, .align_items = .center }, "status-path");
        ui.text(c, info.path, .{ .size = 11.5, .color = th.muted, .truncate = .middle });
        ui.end(c);
        rule(c);
    }
    if (info.position.len > 0) {
        _ = c.open(.{ .align_items = .center }, "status-pos");
        item(c, info.position, th.muted, true);
        ui.end(c);
        rule(c);
    }
    _ = c.open(.{ .align_items = .center }, "status-words");
    item(c, c.print("{d} words", .{info.words}), th.muted, false);
    ui.end(c);
    rule(c);
    _ = c.open(.{ .align_items = .center }, "status-zoom");
    item(c, c.print("Zoom {d}%", .{@as(u32, @intFromFloat(@round(info.zoom * 100)))}), th.muted, true);
    ui.end(c);

    ui.spacer(c);
    if (info.message.len > 0) {
        _ = c.open(.{ .align_items = .center, .gap = 6 }, "status-message");
        _ = c.leaf(.{ .width = .{ .px = 6 }, .height = .{ .px = 6 }, .background = statusColor(th, info.message_kind) }, .none, null);
        ui.text(c, info.message, .{ .size = 11.5, .color = statusColor(th, info.message_kind), .truncate = .ellipsis });
        ui.end(c);
        rule(c);
    }
    // The keys, as the design has them: the hint last, the keys in it muted.
    const hints = [_][]const u8{ "Ctrl+P Open", "Ctrl+Shift+F Search all", "Ctrl+S Save" };
    for (hints, 0..) |hint, i| {
        if (i > 0) rule(c);
        _ = c.open(.{ .align_items = .center }, "status-hint");
        item(c, hint, th.muted.alpha(0.85), false);
        ui.end(c);
    }
}
