//! Left sidebar (~240 px): a hardcoded folder tree, then a "Linked files"
//! section. Clicking a file selects it; clicking a folder toggles it open.
const ui = @import("nanoui").ui;
const theme = @import("theme.zig");

pub const Folder = struct {
    name: []const u8,
    open: bool,
    files: []const []const u8,
};

pub const Sidebar = struct {
    selected: ?[2]usize = null,
    folders: []Folder = &.{},

    pub fn view(s: *Sidebar, c: *ui.Context) void {
        const th = c.theme;
        ui.column(c, .{
            .width = .{ .px = 240 },
            .height = .fill,
            .padding = .xy(12, 10),
            .gap = 4,
            .background = th.surface,
            .border = th.border,
            .border_width = 1,
        });
        defer ui.end(c);
        ui.text(c, "Library", .{ .size = 12, .weight = .semibold, .color = th.muted });
        for (s.folders, 0..) |*f, fi| {
            s.folder(f, fi, c);
        }
        ui.spacer(c);
        ui.text(c, "Linked files", .{ .size = 12, .weight = .semibold, .color = th.muted });
        const links = [_][]const u8{ "spec.md", "notes.md", "draft.txt" };
        for (links, 0..) |name, i| {
            s.link(name, i, c);
        }
    }

    fn folder(s: *Sidebar, f: *Folder, fi: usize, c: *ui.Context) void {
        const th = c.theme;
        const it = ui.pressable(c, .{
            .direction = .row, .width = .fill, .gap = 6, .padding = .xy(7, 5), .align_items = .center,
            .control = true,
        }, th.surface_hover);
        if (it.clicked) { f.open = !f.open; c.changed = true; }
        ui.text(c, if (f.open) "▾ " else "▸ ", .{ .color = th.muted });
        ui.text(c, f.name, .{ .weight = .medium, .color = th.text });
        ui.end(c);
        if (f.open) for (f.files, 0..) |name, i| {
            s.file(name, .{ fi , i }, c);
        };
    }

    fn file(s: *Sidebar, name: []const u8, at: [2]usize, c: *ui.Context) void {
        const th = c.theme;
        const sel = if(s.selected) |p| p[0] == at[0] and p[1] == at[1] else false;
        const it = ui.pressable(c, .{
            .direction = .row, .width = .fill, .gap = 6, .padding = .xy(7, 4), .align_items = .center,
            .control = true,
        }, th.surface_hover);
        if (it.clicked) { s.selected = at; c.changed = true; }
        ui.text(c, "▪ ", .{ .size = 11, .color = th.muted });
        ui.text(c, name, .{ .size = 12, .weight = if (sel) .semibold else .regular, .color = if (sel) th.accent else th.text });
        ui.end(c);
    }

    fn link(s: *Sidebar, name: []const u8, i: usize, c: *ui.Context) void {
        _= s;
        _ = i;
        
        const th = c.theme;
        const it = ui.pressable(c, .{
            .direction = .row, .width = .fill, .gap = 6, .padding = .xy(7, 4), .align_items = .center,
            .control = true,
        }, th.surface_hover);

        _ = it;
        
        ui.text(c, "⇗ ", .{ .size = 11, .color = th.muted });
        ui.text(c, name, .{ .size = 12, .color = th.text });
        ui.end(c);
    }
};
