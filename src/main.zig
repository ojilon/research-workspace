const std = @import("std");
const nanoui = @import("nanoui");
const ui = nanoui.ui;

const App = struct {
    fn view(_: *App, c: *ui.Context) void {
        const root = ui.div(c).column().sizeFull().center().gap(16);
        defer root.end();
        ui.text(c, "revise", .{ .size = 32, .weight = .bold });
        ui.text(c, "Empty window — scaffold OK.", .{ .color = c.theme.muted });
    }
};

pub fn main(init: std.process.Init) !void {
    const app = try nanoui.App.create(init, .{ .name = "revise" });
    defer app.destroy();
    var state: App = .{};
    _ = try app.newWindow(.{
        .title = "revise",
        .width = 1000,
        .height = 700,
        .min_width = 600,
        .min_height = 400,
        .theme = nanoui.ui.Theme.dark_theme,
        .content = .{ .view = .init(&state, App.view) },
    });
    try app.run();
}
