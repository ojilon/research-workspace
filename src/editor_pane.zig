//! The bottom pane: the summary editor. A toolbar (Bold, Italic, Save and the
//! saved/modified state) over a plain-text area holding the document's marker
//! text, with its own scrolling and caret.
const std = @import("std");
const ui = @import("nanoui").ui;
const fsops = @import("fsops.zig");
const paths = @import("paths.zig");

pub const SaveState = enum { idle, saved, working, failed };

pub const State = struct {
    /// The editor's selection as last seen: [anchor, caret] byte offsets.
    sel: [2]usize = .{ 0, 0 },
    /// The area's height in text lines, worked out from the last frame.
    rows: u16 = 12,
    /// The editor had the keyboard in the last frame.
    focused: bool = false,
    /// Its box's id last frame (debugging the layout).
    id: u64 = 0,
};

pub fn view(app: anytype, c: *ui.Context, tab: anytype, grow: f32) void {
    const th = c.theme;
    ui.key(c, "editor-pane");
    const pane_id = c.peekId(null);
    tab.editor.id = pane_id;
    ui.column(c, .{
        .width = .fill,
        .height = .fill,
        .grow = grow,
        .gap = 0,
        .background = th.background,
    });

    // The toolbar.
    ui.row(c, .{
        .width = .fill,
        .height = .{ .px = 34 },
        .padding = .xy(8, 0),
        .gap = 6,
        .align_items = .center,
        .border = th.border,
    });
    if (ui.button(c, "Bold", .{ .variant = .ghost, .size = 12 }).clicked) app.boldSelection(c, tab);
    if (ui.button(c, "Italic", .{ .variant = .ghost, .size = 12 }).clicked) app.italicSelection(c, tab);
    toolbarRule(c);
    if (ui.button(c, "H2", .{ .variant = .ghost, .size = 12 }).clicked) app.headingLine(c, tab);
    if (ui.button(c, "•", .{ .variant = .ghost, .size = 12 }).clicked) app.bulletLine(c, tab);
    toolbarRule(c);
    if (ui.button(c, "Save", .{ .variant = .primary, .size = 12 }).clicked) app.saveActive(c);
    ui.spacer(c);
    stateText(app, c, tab);
    ui.end(c);

    // The text area, sized to the room that is left.
    const pane_h: f32 = if (c.rects.get(pane_id)) |r| r.h else 300;
    const lh = c.text.font(.{ .size = 13.5 }).lineHeight();
    const rows: u16 = @intFromFloat(std.math.clamp(@floor((pane_h - 34 - 16) / @max(lh, 1)), 3, 200));
    tab.editor.rows = rows;

    _ = c.open(.{
        .width = .fill,
        .grow = 1,
        .padding = .{ .left = 14, .right = 14, .top = 8, .bottom = 8 },
    }, "editor-body");
    const result = ui.textArea(c, &tab.buffer, .{
        .placeholder = tab.placeholder,
        .width = .fill,
        .size = 13.5,
        .min_lines = @intCast(@min(rows, 255)),
        .max_lines = @intCast(@min(rows, 255)),
        .submit_on_return = false,
        .bare = true,
        .selection_color = th.accent.alpha(0.28),
        .color = th.text,
    });
    if (result.focused) {
        if (c.focused_text) |ft| tab.editor.sel = .{ ft.anchor, ft.caret };
    }
    tab.editor.focused = result.focused;
    ui.end(c);
    ui.end(c);
}

fn toolbarRule(c: *ui.Context) void {
    _ = c.leaf(.{
        .width = .{ .px = 1 },
        .height = .{ .px = 14 },
        .background = c.theme.border,
    }, .none, "toolbar-rule");
}

fn stateText(app: anytype, c: *ui.Context, tab: anytype) void {
    const th = c.theme;
    switch (tab.save_state) {
        .working => ui.text(c, "working…", .{ .size = 11.5, .color = th.accent }),
        .failed => ui.text(c, tab.save_message, .{ .size = 11.5, .color = th.danger, .truncate = .ellipsis }),
        .saved, .idle => {
            if (tab.dirty) {
                ui.text(c, "● unsaved changes", .{ .size = 11.5, .color = th.accent });
            } else if (tab.save_state == .saved or fsops.exists(app.io, tab.save_path)) {
                // "✓ Saved to Summary-Enzymes.docx", as in the design.
                ui.text(c, c.print("✓ Saved to {s}", .{paths.basename(tab.save_path)}), .{ .size = 11.5, .color = th.muted });
            } else {
                ui.text(c, "no summary yet", .{ .size = 11.5, .color = th.muted });
            }
        },
    }
}
