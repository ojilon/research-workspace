//! The left sidebar: the open folder's tree (folders expand and collapse),
//! the linked ("foreign") files, and the rows that create files and folders.
//! The tree is read from disk here; opening a document is the app's job.
const std = @import("std");
const ui = @import("nanoui").ui;
const fsops = @import("fsops.zig");
const paths = @import("paths.zig");

pub const width: f32 = 240;

pub const Link = struct {
    alias: []u8,
    path: []u8,
};

/// A linked file as the app has it: borrowed, the sidebar keeps its own copy.
pub const LinkView = struct {
    alias: []const u8,
    path: []const u8,
};

pub const Node = struct {
    path: []u8,
    name: []u8,
    is_dir: bool,
    /// How deep in the tree it is, for indentation.
    depth: u32 = 0,
    open: bool = false,
    /// Its folder has been read from disk.
    loaded: bool = false,
    children: std.ArrayList(*Node) = .empty,
};

pub const Action = union(enum) {
    none,
    /// A file was clicked.
    open_file: []const u8,
    new_file,
    new_folder,
    add_foreign,
    /// The magnifier in the heading: search everything.
    search_all,
};

pub const Sidebar = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    roots: std.ArrayList(*Node) = .empty,
    /// Paths of the folders that are open, so a refresh keeps them open.
    open_paths: std.StringHashMapUnmanaged(void) = .empty,
    selected: ?[]u8 = null,
    linked: std.ArrayList(Link) = .empty,
    /// Visible rows, rebuilt every frame.
    rows: std.ArrayList(*Node) = .empty,
    /// Set by `reload` when the folder could not be read.
    load_error: ?[]const u8 = null,
    /// The open folder's own name, shown in the heading (design 01).
    title: []u8 = &.{},

    pub fn init(gpa: std.mem.Allocator, io: std.Io) Sidebar {
        return .{ .gpa = gpa, .io = io };
    }

    pub fn deinit(self: *Sidebar) void {
        if (self.title.len > 0) self.gpa.free(self.title);
        self.clearNodes();
        self.roots.deinit(self.gpa);
        self.rows.deinit(self.gpa);
        var it = self.open_paths.keyIterator();
        while (it.next()) |k| self.gpa.free(k.*);
        self.open_paths.deinit(self.gpa);
        for (self.linked.items) |l| {
            self.gpa.free(l.alias);
            self.gpa.free(l.path);
        }
        self.linked.deinit(self.gpa);
        if (self.selected) |s| self.gpa.free(s);
        self.* = undefined;
    }

    fn clearNodes(self: *Sidebar) void {
        for (self.roots.items) |n| freeNode(self.gpa, n);
        self.roots.clearRetainingCapacity();
        self.rows.clearRetainingCapacity();
    }

    fn freeNode(gpa: std.mem.Allocator, node: *Node) void {
        for (node.children.items) |child| freeNode(gpa, child);
        node.children.deinit(gpa);
        gpa.free(node.path);
        gpa.free(node.name);
        gpa.destroy(node);
    }

    pub fn isSelected(self: *const Sidebar, path: []const u8) bool {
        const sel = self.selected orelse return false;
        return std.mem.eql(u8, sel, path);
    }

    pub fn select(self: *Sidebar, path: []const u8) void {
        if (self.selected) |s| {
            if (std.mem.eql(u8, s, path)) return;
            self.gpa.free(s);
        }
        self.selected = self.gpa.dupe(u8, path) catch null;
    }

    fn loadChildren(self: *Sidebar, node: *Node) !void {
        for (node.children.items) |c| freeNode(self.gpa, c);
        node.children.clearRetainingCapacity();
        const listing = try fsops.listDir(self.gpa, self.io, node.path);
        defer listing.deinit(self.gpa);
        for (listing.entries) |entry| {
            const child_path = try paths.join(self.gpa, &.{ node.path, entry.name });
            const child = try self.gpa.create(Node);
            child.* = .{
                .path = child_path,
                .name = try self.gpa.dupe(u8, entry.name),
                .is_dir = entry.is_dir,
                .depth = node.depth + 1,
            };
            try node.children.append(self.gpa, child);
        }
        node.loaded = true;
    }

    /// Reads the folder again, keeping which folders are open and what is
    /// selected. Called at startup and after a file or folder is created.
    pub fn reload(self: *Sidebar, root: []const u8) void {
        if (self.title.len > 0) self.gpa.free(self.title);
        self.title = self.gpa.dupe(u8, paths.basename(root)) catch &.{};
        self.clearNodes();
        self.load_error = null;
        const listing = fsops.listDir(self.gpa, self.io, root) catch |err| {
            self.load_error = @errorName(err);
            return;
        };
        defer listing.deinit(self.gpa);
        for (listing.entries) |entry| {
            const path = paths.join(self.gpa, &.{ root, entry.name }) catch continue;
            const node = self.gpa.create(Node) catch continue;
            node.* = .{
                .path = path,
                .name = self.gpa.dupe(u8, entry.name) catch continue,
                .is_dir = entry.is_dir,
            };
            self.roots.append(self.gpa, node) catch continue;
        }
        // Re-open what was open before the refresh.
        for (self.roots.items) |node| self.restoreOpen(node);
    }

    fn restoreOpen(self: *Sidebar, node: *Node) void {
        if (!node.is_dir) return;
        if (self.open_paths.contains(node.path)) {
            node.open = true;
            self.loadChildren(node) catch {};
            for (node.children.items) |child| self.restoreOpen(child);
        }
    }

    fn toggle(self: *Sidebar, node: *Node) void {
        node.open = !node.open;
        if (node.open) {
            self.loadChildren(node) catch {};
            self.open_paths.put(self.gpa, self.gpa.dupe(u8, node.path) catch return, {}) catch {};
        } else {
            if (self.open_paths.fetchRemove(node.path)) |kv| self.gpa.free(kv.key);
        }
    }

    pub fn setLinked(self: *Sidebar, items: []const LinkView) void {
        for (self.linked.items) |l| {
            self.gpa.free(l.alias);
            self.gpa.free(l.path);
        }
        self.linked.clearRetainingCapacity();
        for (items) |item| {
            self.linked.append(self.gpa, .{
                .alias = self.gpa.dupe(u8, item.alias) catch continue,
                .path = self.gpa.dupe(u8, item.path) catch continue,
            }) catch {};
        }
    }

    fn flatten(self: *Sidebar, node: *Node) void {
        self.rows.append(self.gpa, node) catch return;
        if (node.is_dir and node.open) {
            for (node.children.items) |child| self.flatten(child);
        }
    }

    pub fn view(self: *Sidebar, c: *ui.Context) Action {
        const th = c.theme;
        var action: Action = .none;
        self.rows.clearRetainingCapacity();
        for (self.roots.items) |node| self.flatten(node);

        ui.column(c, .{
            .width = .{ .px = width },
            .height = .fill,
            .background = th.background,
            .padding = .{ .left = 8, .right = 8, .top = 10, .bottom = 8 },
            .gap = 0,
        });

        // The heading: the folder's name, and the way into search.
        ui.row(c, .{ .width = .fill, .height = .{ .px = 24 }, .align_items = .center });
        ui.text(c, self.title, .{ .size = 12.5, .weight = .semibold, .color = th.text, .truncate = .ellipsis });
        ui.spacer(c);
        ui.key(c, "sidebar-find");
        const find = ui.pressable(c, .{
            .padding = .xy(6, 1),
            .align_items = .center,
            .control = true,
        }, th.surface_hover);
        ui.text(c, "Find", .{ .size = 11, .color = if (find.hovered) th.text else th.muted });
        ui.end(c);
        ui.end(c); // the heading row
        if (find.clicked) action = .search_all;

        // The rows that create things, above the tree as in the design.
        if (self.actionRow(c, "+  New file", "new-file")) action = .new_file;
        if (self.actionRow(c, "+  New folder", "new-folder")) action = .new_folder;
        _ = c.leaf(.{ .width = .fill, .height = .{ .px = 6 } }, .none, "sidebar-gap");
        _ = c.leaf(.{ .width = .fill, .height = .{ .px = 1 }, .background = th.border }, .none, "sidebar-rule-top");

        // The tree.
        var list = ui.list(c, .{
            .count = self.rows.items.len,
            .row_height = 22,
            .width = .fill,
            .height = .fill,
        });
        while (list.next()) |i| {
            const node = self.rows.items[i];
            if (self.viewRow(c, node, action == .none)) |open_path| action = .{ .open_file = open_path };
        }
        list.end();

        if (self.roots.items.len == 0) {
            ui.text(c, "This folder is empty.", .{ .size = 12, .color = th.muted });
        }

        // Linked files, at the foot: they are not in this folder.
        ui.spacer(c);
        _ = c.leaf(.{ .width = .fill, .height = .{ .px = 1 }, .background = th.border }, .none, "sidebar-rule");
        ui.row(c, .{ .width = .fill, .height = .{ .px = 24 }, .align_items = .center });
        ui.text(c, "Linked files", .{ .size = 11, .weight = .semibold, .color = th.muted });
        ui.spacer(c);
        if (self.linked.items.len == 0) ui.text(c, "none", .{ .size = 11, .color = th.muted.alpha(0.7) });
        ui.end(c);

        const shown = @min(self.linked.items.len, 4);
        var li: usize = 0;
        while (li < shown) : (li += 1) {
            if (self.viewLink(c, self.linked.items[li])) |p| action = .{ .open_file = p };
        }
        if (self.actionRow(c, "+  Add foreign file", "add-foreign")) action = .add_foreign;
        ui.end(c);
        return action;
    }

    fn viewRow(self: *Sidebar, c: *ui.Context, node: *Node, active: bool) ?[]const u8 {
        const th = c.theme;
        const selected = self.isSelected(node.path);
        const row = ui.pressable(c, .{
            .direction = .row,
            .width = .fill,
            .height = .{ .px = 22 },
            .align_items = .center,
            .gap = 6,
            .padding = .{ .left = 4 + @as(f32, @floatFromInt(node.depth)) * 12, .right = 4 },
            .background = if (selected) th.accent.alpha(0.16) else th.background,
            .control = true,
        }, th.surface_hover);
        if (selected) {
            _ = c.leaf(.{
                .absolute = true,
                .width = .{ .px = 2 },
                .height = .fill,
                .background = th.accent,
                .offset = .{ .x = -4, .y = 0 },
            }, .none, "selected-bar");
        }
        const glyph = glyphFor(node);
        ui.text(c, glyph, .{
            .size = 11,
            .color = if (node.is_dir) th.muted else th.muted.alpha(0.8),
            .mono = true,
        });
        ui.text(c, node.name, .{
            .size = 12.5,
            .color = if (selected) th.text else if (node.is_dir) th.text else th.text.alpha(0.92),
            .truncate = .ellipsis,
        });
        ui.end(c);

        if (row.clicked and active) {
            if (node.is_dir) {
                self.toggle(node);
                return null;
            }
            self.select(node.path);
            return node.path;
        }
        return null;
    }

    fn viewLink(self: *Sidebar, c: *ui.Context, link: Link) ?[]const u8 {
        const th = c.theme;
        const selected = self.isSelected(link.path);
        const row = ui.pressable(c, .{
            .direction = .column,
            .width = .fill,
            .height = .{ .px = 32 },
            .align_items = .start,
            .justify = .center,
            .gap = 1,
            .padding = .{ .left = 6, .right = 4 },
            .background = if (selected) th.accent.alpha(0.16) else th.background,
            .control = true,
        }, th.surface_hover);
        ui.text(c, link.alias, .{ .size = 12, .color = th.text.alpha(0.92), .truncate = .ellipsis });
        ui.text(c, paths.dirname(link.path), .{ .size = 10, .color = th.muted.alpha(0.75), .truncate = .middle });
        ui.end(c);
        if (row.clicked) {
            self.select(link.path);
            return link.path;
        }
        return null;
    }

    fn actionRow(self: *Sidebar, c: *ui.Context, label: []const u8, key: []const u8) bool {
        _ = self;
        const th = c.theme;
        ui.key(c, key);
        const row = ui.pressable(c, .{
            .direction = .row,
            .width = .fill,
            .height = .{ .px = 24 },
            .align_items = .center,
            .padding = .{ .left = 4 },
            .control = true,
        }, th.surface_hover);
        ui.text(c, label, .{ .size = 12, .color = th.muted });
        ui.end(c);
        return row.clicked;
    }
};

/// The plain-text glyph a file's type gets in the tree.
pub fn glyphFor(node: *Node) []const u8 {
    if (node.is_dir) return if (node.open) "▾" else "▸";
    if (paths.kindOf(node.path)) |kind| return switch (kind) {
        .pdf => "P",
        .docx => "D",
        .text => if (std.ascii.eqlIgnoreCase(std.fs.path.extension(node.path), ".txt")) "T" else "M",
    };
    return "·";
}

test "glyphs name the type" {
    var dir: Node = .{ .path = @constCast("/w/x"), .name = @constCast("x"), .is_dir = true };
    try std.testing.expectEqualStrings("▸", glyphFor(&dir));
    dir.open = true;
    try std.testing.expectEqualStrings("▾", glyphFor(&dir));
    var file: Node = .{ .path = @constCast("/w/a.pdf"), .name = @constCast("a.pdf"), .is_dir = false };
    try std.testing.expectEqualStrings("P", glyphFor(&file));
    file.path = @constCast("/w/a.docx");
    try std.testing.expectEqualStrings("D", glyphFor(&file));
    file.path = @constCast("/w/a.md");
    try std.testing.expectEqualStrings("M", glyphFor(&file));
    file.path = @constCast("/w/a.txt");
    try std.testing.expectEqualStrings("T", glyphFor(&file));
    file.path = @constCast("/w/a.bin");
    try std.testing.expectEqualStrings("·", glyphFor(&file));
}
