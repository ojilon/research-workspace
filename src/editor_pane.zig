//! Editable multi-line text editor. The toolbar (Bold, Italic, Save) is
//! dummy and non-functional for now; the area is nanoui's textArea with
//! selection, undo and scroll built in.
const ui = @import("nanoui").ui;
const theme = @import("theme.zig");

pub const Editor = struct {
    buffer: ui.TextBuffer = .{},
    dirty: bool = false,

    pub fn view(s: *Editor, c: *ui.Context) void {
        const th = c.theme;
        _ = ui.div(c).column().wFull().grow().bg(th.surface).border(th.border).borderW(1);
        defer c.end();
        // toolbar
        const bar = ui.div(c).row().wFull().h(30).itemsCenter().gap(8).px(8);
        //defer bar.end();
        if (ui.button(c, "Bold", .{ .variant = .ghost, .size = 12 }).clicked) {}
        if (ui.button(c, "Italic", .{ .variant = .ghost, .size = 12 }).clicked) {}
        if (ui.button(c, "Save", .{ .variant = .secondary, .size = 12 }).clicked) {}
        ui.spacer(c);
        ui.label(c, "modified");
        _ = c.leaf(.{ .absolute = true, .offset = .{ .y = 29 }, .width = .fill, .height = .{ .px = 1 }, .background = th.border }, .none, null);

        //close the tool bar before the text area starts
        bar.end();
        // editor: min height makes the pane look substantial; it scrolls
        // once the text passes max_lines.
        const r = ui.textArea(c, &s.buffer, .{
            .bare = true,
            .min_lines = 6,
            .max_lines = 14,
            .submit_on_return = false,
            .placeholder = "Type your notes here…",
        });
        if(r.changed) s.dirty = true;
    }
};
