//! The menu bar along the top of the window (design 01): File, Edit, View, Go
//! and Help, each a label that opens a flat list of commands with their keys
//! on the right. Every command is also a keyboard shortcut; the menu is for
//! finding them, not for being the only way in.
const std = @import("std");
const ui = @import("nanoui").ui;

pub const Command = enum {
    new_file,
    new_folder,
    open_folder,
    add_foreign,
    quit,
    save,
    bold,
    italic,
    heading,
    bullet,
    add_to_summary,
    zoom_in,
    zoom_out,
    zoom_reset,
    theme,
    reindex,
    search_all,
    quick_open,
    goto_page,
    next_tab,
    close_tab,
    shortcuts,
    about,
};

const Item = struct {
    label: []const u8,
    keys: []const u8 = "",
    command: Command,
    /// A line between groups of items.
    rule_after: bool = false,
};

const Menu = struct {
    label: []const u8,
    items: []const Item,
};

const menus = [_]Menu{
    .{ .label = "File", .items = &.{
        .{ .label = "New file…", .keys = "Ctrl+N", .command = .new_file },
        .{ .label = "New folder…", .keys = "Ctrl+Shift+N", .command = .new_folder },
        .{ .label = "Open folder…", .keys = "Ctrl+O", .command = .open_folder, .rule_after = true },
        .{ .label = "Add foreign file…", .command = .add_foreign, .rule_after = true },
        .{ .label = "Quit", .keys = "Ctrl+Q", .command = .quit },
    } },
    .{ .label = "Edit", .items = &.{
        .{ .label = "Save", .keys = "Ctrl+S", .command = .save, .rule_after = true },
        .{ .label = "Bold", .keys = "Ctrl+B", .command = .bold },
        .{ .label = "Italic", .keys = "Ctrl+I", .command = .italic },
        .{ .label = "Heading", .keys = "", .command = .heading },
        .{ .label = "Bullet", .keys = "", .command = .bullet, .rule_after = true },
        .{ .label = "Add to summary", .command = .add_to_summary },
    } },
    .{ .label = "View", .items = &.{
        .{ .label = "Zoom in", .keys = "Ctrl+=", .command = .zoom_in },
        .{ .label = "Zoom out", .keys = "Ctrl+-", .command = .zoom_out },
        .{ .label = "Actual size", .keys = "Ctrl+0", .command = .zoom_reset, .rule_after = true },
        .{ .label = "Light theme", .keys = "Ctrl+Shift+D", .command = .theme, .rule_after = true },
        .{ .label = "Refresh the index", .keys = "Ctrl+R", .command = .reindex },
    } },
    .{ .label = "Go", .items = &.{
        .{ .label = "Search all files…", .keys = "Ctrl+Shift+F", .command = .search_all },
        .{ .label = "Open a file…", .keys = "Ctrl+P", .command = .quick_open },
        .{ .label = "Go to page…", .keys = "Ctrl+G", .command = .goto_page, .rule_after = true },
        .{ .label = "Next tab", .keys = "Ctrl+Tab", .command = .next_tab, .rule_after = true },
        .{ .label = "Close tab", .keys = "Ctrl+W", .command = .close_tab },
    } },
    .{ .label = "Help", .items = &.{
        .{ .label = "Keyboard shortcuts", .command = .shortcuts },
        .{ .label = "About revise", .command = .about },
    } },
};

pub const State = struct {
    /// Which menu is open: an index into `menus`.
    open: ?usize = null,
    /// The label boxes' x, so a panel can be placed under its label.
    xs: [menus.len]f32 = @splat(0),
    ws: [menus.len]f32 = @splat(0),

    pub fn close(self: *State) void {
        self.open = null;
    }
};

pub const width: f32 = 28;

/// Draws the bar and, when one is open, its list. Returns the command picked
/// this frame.
pub fn view(state: *State, c: *ui.Context) ?Command {
    const th = c.theme;
    var chosen: ?Command = null;
    var clicked_label = false;
    ui.row(c, .{
        .width = .fill,
        .height = .{ .px = width },
        .padding = .xy(8, 0),
        .align_items = .center,
        .gap = 2,
        .background = th.background,
    });
    for (menus, 0..) |menu, i| {
        ui.keyInt(c, i);
        const id = c.peekId(null);
        const is_open = state.open == i;
        const it = ui.pressable(c, .{
            .padding = .xy(10, 3),
            .align_items = .center,
            .background = if (is_open) th.surface else null,
            .control = true,
        }, th.surface_hover);
        if (c.rects.get(id)) |r| {
            state.xs[i] = r.x;
            state.ws[i] = r.w;
        }
        ui.text(c, menu.label, .{
            .size = 12,
            .color = if (is_open or it.hovered) th.text else th.muted,
        });
        ui.end(c);
        if (it.clicked) {
            state.open = if (is_open) null else i;
            clicked_label = true;
            c.changed = true;
        }
    }
    _ = c.leaf(.{ .grow = 1 }, .none, null);
    ui.text(c, "revise", .{ .size = 10.5, .color = th.muted.alpha(0.6) });
    ui.end(c);

    // The list of the open menu, over the page.
    const which = state.open orelse return null;
    const menu = menus[which];
    const panel_w: f32 = 240;
    var h: f32 = 8;
    for (menu.items) |item| h += if (item.rule_after) 30.5 else 26;

    ui.column(c, .{
        .absolute = true,
        .fixed = true,
        .layer = 3,
        .offset = .{ .x = state.xs[which], .y = width },
        .width = .{ .px = panel_w },
        .padding = .{ .left = 4, .right = 4, .top = 4, .bottom = 4 },
        .background = th.surface,
        .border = th.border,
    });
    for (menu.items, 0..) |item, i| {
        ui.keyInt(c, 100 + i);
        const row = ui.pressable(c, .{
            .direction = .row,
            .width = .fill,
            .height = .{ .px = 26 },
            .align_items = .center,
            .padding = .xy(8, 0),
            .gap = 8,
            .control = true,
        }, th.surface_hover);
        ui.text(c, item.label, .{ .size = 12, .color = th.text });
        ui.spacer(c);
        if (item.keys.len > 0) ui.text(c, item.keys, .{ .size = 10.5, .color = th.muted.alpha(0.8) });
        ui.end(c);
        if (row.clicked) {
            chosen = item.command;
            state.open = null;
        }
        if (item.rule_after) {
            _ = c.leaf(.{ .width = .fill, .height = .{ .px = 1 }, .background = th.border }, .none, null);
        }
    }
    ui.end(c);

    // A click anywhere else closes the menu.
    if (c.input.pressed and !clicked_label and state.open != null) state.open = null;
    return chosen;
}

test "every command is reachable" {
    const all = std.meta.tags(Command);
    var seen: [all.len]bool = @splat(false);
    for (menus) |menu| {
        for (menu.items) |item| {
            const i = @intFromEnum(item.command);
            try std.testing.expect(!seen[i]);
            seen[i] = true;
        }
    }
    for (seen) |s| try std.testing.expect(s);
}
