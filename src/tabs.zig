//! The tab strip: one tab per open document, its unsaved dot, and its close
//! button. Tabs take the width their names need (up to a limit) instead of
//! being stretched into equal thirds.
const ui = @import("nanoui").ui;

pub const Item = struct {
    name: []const u8,
    /// A file-type glyph: P, D, M, T (as in the sidebar).
    glyph: []const u8 = "",
    dirty: bool = false,
    active: bool = false,
    /// A tool is working on this tab (save or extraction in progress).
    busy: bool = false,
};

pub const Action = union(enum) {
    none,
    select: usize,
    close: usize,
    /// The "+" at the right of the strip: open a file.
    new_tab,
};

const tab_min: f32 = 120;
const tab_max: f32 = 220;

pub fn view(c: *ui.Context, items: []const Item) Action {
    const th = c.theme;
    var action: Action = .none;
    ui.column(c, .{ .width = .fill, .gap = 0 });
    ui.row(c, .{
        .width = .fill,
        .height = .{ .px = 36 },
        .align_items = .stretch,
        .background = th.background,
        .padding = .{ .left = 2, .right = 2 },
    });

    for (items, 0..) |item, i| {
        ui.keyInt(c, i);
        const base = if (item.active) th.surface else th.background;
        const it = ui.pressable(c, .{
            .direction = .row,
            .height = .fill,
            .min_width = tab_min,
            .max_width = tab_max,
            .padding = .{ .left = 12, .right = 6 },
            .align_items = .center,
            .gap = 8,
            .background = base,
            .control = true,
        }, th.surface_hover);
        c.addA11y(c.stack.items[c.stack.items.len - 1], .tab, item.name, "", item.active, true);
        if (it.clicked) action = .{ .select = i };
        if (it.middle_clicked) action = .{ .close = i };

        if (item.glyph.len > 0) {
            ui.text(c, item.glyph, .{
                .size = 10,
                .mono = true,
                .color = if (item.active) th.muted else th.muted.alpha(0.7),
            });
        }

        // The name takes the room, the dot and the close button take theirs.
        _ = c.open(.{ .grow = 1, .align_items = .center }, "tab-name");
        ui.text(c, item.name, .{
            .size = 12.5,
            .weight = if (item.active) .medium else .regular,
            .color = if (item.active) th.text else th.muted,
            .truncate = .ellipsis,
        });
        ui.end(c);

        if (item.busy or item.dirty) {
            _ = c.leaf(.{
                .width = .{ .px = 6 },
                .height = .{ .px = 6 },
                .radius = 3,
                .background = if (item.busy) th.accent else th.muted,
            }, .none, "tab-dot");
        }

        // The close button: a wider hit area than its glyph.
        const close_hover = if (item.active) th.surface_hover else th.background;
        const close = ui.pressable(c, .{
            .width = .{ .px = 18 },
            .height = .{ .px = 18 },
            .align_items = .center,
            .justify = .center,
            .control = true,
        }, close_hover);
        if (close.clicked) action = .{ .close = i };
        ui.text(c, "×", .{ .size = 13, .color = if (close.hovered) th.text else th.muted });
        ui.end(c);

        // The accent underline of the active tab, along its bottom edge.
        if (item.active) {
            _ = c.leaf(.{
                .absolute = true,
                .width = .fill,
                .height = .{ .px = 2 },
                .background = th.accent,
                .offset = .{ .x = 0, .y = 34 },
            }, .none, "tab-accent");
        }
        ui.end(c);
    }
    ui.spacer(c);
    ui.key(c, "tab-new");
    const plus = ui.pressable(c, .{
        .width = .{ .px = 26 },
        .height = .fill,
        .align_items = .center,
        .justify = .center,
        .control = true,
    }, th.surface_hover);
    if (plus.clicked) action = .new_tab;
    ui.text(c, "+", .{ .size = 14, .color = if (plus.hovered) th.text else th.muted });
    ui.end(c);
    ui.end(c); // the row
    // The 1 px line under the strip.
    _ = c.leaf(.{ .width = .fill, .height = .{ .px = 1 }, .background = th.border }, .none, "tabs-rule");
    ui.end(c); // the strip column
    return action;
}
