//! The application: the frame layout, the open documents, the keys, and the
//! one Python process the app may be waiting on.
//!
//! Layout, top to bottom: the sidebar (240 px) beside a column of the tab
//! strip, the reader, a draggable divider and the summary editor; then the
//! status bar. Overlays are drawn last, on a layer above everything.
const std = @import("std");
const nanoui = @import("nanoui");
const ui = nanoui.ui;
const model = @import("model.zig");
const paths = @import("paths.zig");
const markers = @import("markers.zig");
const fsops = @import("fsops.zig");
const pybridge = @import("pybridge.zig");
const theme = @import("theme.zig");
const sidebar = @import("sidebar.zig");
const tabs = @import("tabs.zig");
const reader_pane = @import("reader_pane.zig");
const editor_pane = @import("editor_pane.zig");
const statusbar = @import("statusbar.zig");
const overlays = @import("overlays.zig");
const menu_bar = @import("menu_bar.zig");

pub const min_split: f32 = 0.25;
pub const max_split: f32 = 0.75;

pub const Tab = struct {
    doc: *model.Doc,
    path: []u8,
    name: []u8,
    kind: paths.Kind,
    /// Where Ctrl+S writes: the summary `.docx`, or a text file itself.
    save_path: []u8,
    buffer: ui.TextBuffer,
    /// The editor's text as it was last saved: what "modified" compares with.
    saved_text: []u8,
    dirty: bool = false,
    save_state: editor_pane.SaveState = .idle,
    save_message: []const u8 = "",
    reader: reader_pane.State = .{},
    editor: editor_pane.State = .{},
    highlights: ?*model.HighlightList = null,
    /// A tool is working on this tab.
    busy: bool = false,
    /// Shown when the editor is empty.
    placeholder: []u8,

    pub fn deinit(self: *Tab, gpa: std.mem.Allocator) void {
        self.doc.deinit(gpa);
        gpa.free(self.path);
        gpa.free(self.name);
        gpa.free(self.save_path);
        gpa.free(self.saved_text);
        gpa.free(self.placeholder);
        self.buffer.deinit();
        self.reader.deinit(gpa);
        if (self.highlights) |h| h.deinit(gpa);
        gpa.destroy(self);
    }
};

const PendingKind = enum {
    index,
    open_doc,
    open_summary,
    save,
    highlights,
    search,
    files,
    links,
    new_file,
    add_link,
    add_highlight,
};

const Pending = struct {
    kind: PendingKind,
    tool: pybridge.Tool = .extract,
    tab: ?*Tab = null,
    /// The file the request is about.
    path: []u8 = "",
    /// The query, or the markers file, or a second argument.
    arg: []u8 = "",
    /// A highlight's text.
    extra: []u8 = "",
    overwrite: bool = false,

    fn deinit(self: *Pending, gpa: std.mem.Allocator) void {
        if (self.path.len > 0) gpa.free(self.path);
        if (self.arg.len > 0) gpa.free(self.arg);
        if (self.extra.len > 0) gpa.free(self.extra);
    }
};

pub const App = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    runner: pybridge.Runner,
    /// Frame memory: dialogs and formatted strings, reset every frame.
    arena: std.heap.ArenaAllocator,
    win: ?*nanoui.Window = null,
    root: []u8,
    cwd: []u8,
    tabs: std.ArrayList(*Tab) = .empty,
    active: usize = 0,
    sidebar: sidebar.Sidebar,
    zoom_value: f32 = 1,
    split: f32 = 0.55,
    dragging: bool = false,
    last_mouse_y: f32 = 0,
    dark: bool = true,
    overlay: overlays.State = .{},
    menu: menu_bar.State = .{},
    search: ?*model.SearchResults = null,
    search_loading: bool = false,
    search_inflight: []u8 = "",
    files: ?*model.FileList = null,
    files_loading: bool = false,
    conflict_path: []const u8 = "",
    /// The folder new files and folders go into.
    target_dir: []const u8 = "",
    /// Set by the reader when a block is clicked (the toolbar redraws).
    selection_changed: bool = false,
    editor_focused: bool = false,
    queue: std.ArrayList(Pending) = .empty,
    current: ?Pending = null,
    counter: u64 = 0,
    status_message: []u8 = "",
    status_kind: statusbar.Kind = .plain,
    status_until: f64 = 0,
    title_buf: [512]u8 = undefined,
    title_len: usize = 0,
    index_total: usize = 0,
    debug_layout: bool = false,
    dbg_panes: u64 = 0,
    dbg_editor: u64 = 0,
    indexing: bool = false,
    /// A page to jump to once the document named has finished opening.
    jump_after_open: ?struct { path: []u8, page: u32 } = null,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, env: *const std.process.Environ.Map) !*App {
        const self = try gpa.create(App);
        errdefer gpa.destroy(self);
        const here = try std.process.currentPathAlloc(io, gpa);
        defer gpa.free(here);
        const cwd = try gpa.dupe(u8, here);
        self.* = .{
            .gpa = gpa,
            .io = io,
            .runner = try pybridge.Runner.init(gpa, io, env),
            .arena = std.heap.ArenaAllocator.init(gpa),
            .root = try gpa.dupe(u8, cwd),
            .cwd = cwd,
            .sidebar = sidebar.Sidebar.init(gpa, io),
        };
        return self;
    }

    pub fn deinit(self: *App) void {
        for (self.tabs.items) |tab| tab.deinit(self.gpa);
        self.tabs.deinit(self.gpa);
        self.sidebar.deinit();
        self.runner.deinit();
        if (self.search) |s| s.deinit(self.gpa);
        if (self.files) |f| f.deinit(self.gpa);
        for (self.queue.items) |*p| p.deinit(self.gpa);
        self.queue.deinit(self.gpa);
        if (self.current) |*p| p.deinit(self.gpa);
        if (self.search_inflight.len > 0) self.gpa.free(self.search_inflight);
        if (self.jump_after_open) |j| self.gpa.free(j.path);
        if (self.status_message.len > 0) self.gpa.free(self.status_message);
        self.overlay.deinit();
        self.arena.deinit();
        self.gpa.free(self.root);
        self.gpa.free(self.cwd);
        self.gpa.destroy(self);
    }

    /// Sets the folder that is open (the command line's, or the one chosen).
    pub fn setRoot(self: *App, path: []const u8) void {
        const abs = paths.absoluteNorm(self.gpa, path, self.cwd) catch return;
        self.gpa.free(self.root);
        self.root = abs;
        self.sidebar.reload(self.root);
        self.refreshLists();
        self.enqueueIndex();
    }

    /// Called once the window exists: reads the folder and starts looking at
    /// the files in the background.
    pub fn start(self: *App, file_to_open: ?[]const u8) void {
        self.sidebar.reload(self.root);
        self.enqueueIndex();
        if (file_to_open) |p| self.openPathNow(p);
    }

    // --- frame --------------------------------------------------------------

    pub fn view(self: *App, c: *ui.Context) void {
        _ = self.arena.reset(.retain_capacity);
        // nanoui resets the theme from the system before each frame; the
        // app's own choice wins, before anything is drawn.
        c.theme = theme.pick(self.dark);
        self.target_dir = self.targetDir();
        self.pollJobs(c);
        self.handleShortcuts(c);
        self.updateTitle();
        self.expireStatus(c);

        const th = c.theme;
        // Every region paints its own background: the window's clear colour
        // is the system's dark or light, and would show through a gap when
        // the app's theme is the other one.
        ui.column(c, .{ .width = .fill, .height = .fill, .gap = 0, .background = th.background });
        if (menu_bar.view(&self.menu, c)) |cmd| {
            // Running a command may start work: the frame goes on with what
            // the command left behind.
            self.runCommand(c, cmd);
        }
        ui.row(c, .{ .width = .fill, .grow = 1, .gap = 0 });

        // The sidebar.
        switch (self.sidebar.view(c)) {
            .none => {},
            .open_file => |path| self.openPath(c, path),
            .new_file => overlays.open(self, .new_file),
            .new_folder => overlays.open(self, .new_folder),
            .add_foreign => overlays.open(self, .add_foreign),
            .search_all => overlays.open(self, .search),
        }
        _ = c.leaf(.{ .width = .{ .px = 1 }, .height = .fill, .background = th.border }, .none, "sidebar-rule");

        // The tabs and the two panes. Both heights are `.fill`: in a row a
        // box with an auto height is only as tall as its content.
        ui.column(c, .{ .grow = 1, .width = .fill, .height = .fill, .gap = 0, .background = th.background });
        var item_buf: [32]tabs.Item = undefined;
        const n = @min(self.tabs.items.len, item_buf.len);
        for (self.tabs.items[0..n], 0..) |tab, i| {
            item_buf[i] = .{
                .name = tab.name,
                .glyph = glyphFor(tab.kind),
                .dirty = tab.dirty,
                .active = i == self.active,
                .busy = tab.busy,
            };
        }
        switch (tabs.view(c, item_buf[0..n])) {
            .none => {},
            .select => |i| self.active = i,
            .close => |i| self.closeTab(c, i),
            .new_tab => {
                if (self.files == null) self.refreshLists();
                overlays.open(self, .quick_open);
            },
        }

        ui.key(c, "panes");
        const panes_id = c.peekId(null);
        self.dbg_panes = panes_id;
        ui.column(c, .{ .grow = 1, .width = .fill, .height = .fill, .gap = 0, .background = th.background });
        if (self.activeTab()) |tab| {
            reader_pane.view(self, c, tab, self.split);
        } else {
            ui.column(c, .{ .width = .fill, .grow = self.split, .align_items = .center, .justify = .center, .gap = 6 });
            ui.text(c, "No document open", .{ .size = 14, .color = th.muted });
            ui.text(c, "Pick one on the left, or press Ctrl+P.", .{ .size = 12, .color = th.muted.alpha(0.8) });
            ui.end(c);
        }
        self.divider(c, panes_id);
        if (self.activeTab()) |tab| {
            editor_pane.view(self, c, tab, 1 - self.split);
            self.dbg_editor = tab.editor.id;
            tab.dirty = !std.mem.eql(u8, tab.buffer.text(), tab.saved_text);
        } else {
            ui.column(c, .{ .width = .fill, .grow = 1 - self.split, .background = th.background });
            ui.end(c);
        }
        ui.end(c); // panes
        ui.end(c); // main column
        ui.end(c); // row

        self.selectionToolbar(c);

        // The status bar.
        var info: statusbar.Info = .{
            .path = if (self.activeTab()) |t| t.path else self.root,
            // The document's words while reading, the summary's while writing
            // notes: a PDF's own text is what "2000 words" refers to.
            .words = if (self.activeTab()) |t|
                (if (t.kind == .text) model.countWords(t.buffer.text()) else t.doc.wordCount())
            else
                0,
            .zoom = self.zoom_value,
            .message = self.status_message,
            .message_kind = self.status_kind,
        };
        if (self.activeTab()) |tab| {
            const count = tab.doc.itemCount();
            if (count > 0) {
                info.position = if (tab.doc.isPaged())
                    c.print("Page {d} / {d}", .{ tab.doc.pageNumber(tab.reader.item), count })
                else if (tab.kind == .docx)
                    c.print("¶ {d} / {d}", .{ tab.reader.item + 1, count })
                else
                    c.print("Line {d} / {d}", .{ tab.reader.item + 1, count });
            }
        }
        if (self.runner.busy()) {
            info.message = if (self.indexing) "indexing…" else "working…";
            info.message_kind = .busy;
        }
        statusbar.view(c, info);
        ui.end(c); // root column

        // Everything that floats.
        overlays.view(self, c);
        if (self.debug_layout) {
            const tab = self.activeTab();
            std.debug.print("panes={any} reader={any} editor={any} window {d:.0}x{d:.0}\n", .{
                c.rects.get(self.dbg_panes),
                if (tab) |t| c.rects.get(t.reader.scroll_id) else null,
                c.rects.get(self.dbg_editor),
                c.size.w,
                c.size.h,
            });
        }
        if (self.activeTab()) |tab| {
            if (tab.editor.focused != self.editor_focused) self.editor_focused = tab.editor.focused;
        } else self.editor_focused = false;
        _ = self.selection_changed;
        self.selection_changed = false;
    }

    fn divider(self: *App, c: *ui.Context, panes_id: u64) void {
        const th = c.theme;
        ui.key(c, "divider");
        const it = ui.pressable(c, .{
            .direction = .row,
            .width = .fill,
            .height = .{ .px = 18 },
            .align_items = .center,
            .gap = 12,
            .padding = .xy(20, 0),
            .background = th.background,
        }, null);
        if (it.hovered or it.pressed) c.cursor = .resize_up_down;
        const line = if (it.hovered or it.pressed) th.accent else th.border;
        var label: ?[]const u8 = null;
        if (self.activeTab()) |tab| {
            if (tab.doc.isPaged() and tab.doc.itemCount() > 0) {
                label = c.print("Page {d} / {d}", .{ tab.doc.pageNumber(tab.reader.item), tab.doc.itemCount() });
            }
        }
        if (label) |text| {
            _ = c.leaf(.{ .grow = 1, .height = .{ .px = 1 }, .background = line }, .none, null);
            ui.text(c, text, .{ .size = 10.5, .color = th.muted, .tabular = true });
            _ = c.leaf(.{ .grow = 1, .height = .{ .px = 1 }, .background = line }, .none, null);
        } else {
            _ = c.leaf(.{ .width = .fill, .height = .{ .px = 1 }, .background = line }, .none, null);
        }
        ui.end(c);

        if (it.pressed and c.input.down) {
            if (!self.dragging) {
                self.dragging = true;
                self.last_mouse_y = c.input.mouse.y;
            }
            if (c.rects.get(panes_id)) |r| {
                var next = self.split + (c.input.mouse.y - self.last_mouse_y) / @max(1, r.h);
                next = std.math.clamp(next, min_split, max_split);
                self.last_mouse_y = c.input.mouse.y;
                if (next != self.split) {
                    self.split = next;
                    c.changed = true;
                }
            }
        } else if (self.dragging) {
            self.dragging = false;
        }
    }

    /// Copy / Highlight / Add to summary, shown while a selection or a block
    /// is picked in the reader.
    fn selectionToolbar(self: *App, c: *ui.Context) void {
        const tab = self.activeTab() orelse return;
        const selected = c.selection.text.items;
        const has_block = tab.reader.sel_block != null;
        if (selected.len == 0 and !has_block) return;
        const th = c.theme;
        const w: f32 = 306;
        // Just above the divider, centred on the reader: the reader's own
        // rect from the last frame says where that is.
        // Under the block that was clicked, as the design has it; just above
        // the divider when the block has been scrolled away.
        var x = (c.size.w - w) / 2;
        var y = c.size.h - 120;
        const pane = c.rects.get(tab.reader.scroll_id);
        if (tab.reader.sel_rect) |sel| {
            x = sel.x + (sel.w - w) / 2;
            y = sel.y + sel.h + 6;
        } else if (pane) |r| {
            x = r.x + (r.w - w) / 2;
            y = r.y + r.h - 42;
        }
        if (pane) |r| {
            x = std.math.clamp(x, r.x + 8, r.x + r.w - w - 8);
            if (y + 34 > r.y + r.h) y = r.y + r.h - 40;
            y = @max(y, r.y + 4);
        }
        ui.row(c, .{
            .absolute = true,
            .fixed = true,
            .layer = 1,
            .width = .{ .px = w },
            .height = .{ .px = 34 },
            .offset = .{ .x = x, .y = y },
            .padding = .xy(8, 0),
            .gap = 4,
            .align_items = .center,
            .background = th.surface,
            .border = th.border,
        });
        const text: []const u8 = if (selected.len > 0) selected else (tab.reader.sel_text orelse "");
        if (ui.button(c, "Copy", .{ .variant = .ghost, .size = 11.5 }).clicked) {
            if (text.len > 0) {
                c.clipboard.write(c.clipboard.ctx, text);
                self.toast(c, "Copied", .good, 2);
            }
        }
        if (ui.button(c, "Highlight", .{ .variant = .ghost, .size = 11.5 }).clicked) {
            self.highlightSelection(c, tab, text);
        }
        if (ui.button(c, "Add to summary", .{ .variant = .ghost, .size = 11.5 }).clicked) {
            self.addToSummary(c, tab, text);
        }
        ui.end(c);
    }

    fn updateTitle(self: *App) void {
        const win = self.win orelse return;
        const name = if (self.activeTab()) |t| t.name else paths.basename(self.root);
        var buf: [512]u8 = undefined;
        const title = std.fmt.bufPrint(&buf, "revise — {s}", .{name}) catch return;
        if (title.len == self.title_len and std.mem.eql(u8, self.title_buf[0..self.title_len], title)) return;
        @memcpy(self.title_buf[0..title.len], title);
        self.title_len = title.len;
        win.setTitle(title);
    }

    fn expireStatus(self: *App, c: *ui.Context) void {
        if (self.status_until <= 0) return;
        if (c.time < self.status_until) {
            c.frameIn(@floatCast(@max(0.05, self.status_until - c.time)));
            return;
        }
        self.status_until = 0;
        self.setStatus(c, "", .plain);
    }

    fn setStatus(self: *App, c: *ui.Context, text: []const u8, kind: statusbar.Kind) void {
        _ = c;
        if (self.status_message.len > 0) self.gpa.free(self.status_message);
        self.status_message = if (text.len > 0) self.gpa.dupe(u8, text) catch "" else "";
        self.status_kind = kind;
    }

    pub fn toast(self: *App, c: *ui.Context, text: []const u8, kind: statusbar.Kind, seconds: f64) void {
        self.setStatus(c, text, kind);
        self.status_until = c.time + seconds;
        c.frameIn(@floatCast(seconds));
    }

    // --- documents ----------------------------------------------------------

    pub fn activeTab(self: *App) ?*Tab {
        if (self.tabs.items.len == 0) return null;
        if (self.active >= self.tabs.items.len) self.active = self.tabs.items.len - 1;
        return self.tabs.items[self.active];
    }

    fn tabByPath(self: *App, path: []const u8) ?usize {
        for (self.tabs.items, 0..) |tab, i| {
            if (std.mem.eql(u8, tab.path, path)) return i;
        }
        return null;
    }

    /// Opens a file: switches to it when it is already open, reads it with a
    /// tool when it is not.
    pub fn openPath(self: *App, c: *ui.Context, path: []const u8) void {
        if (self.tabByPath(path)) |i| {
            self.active = i;
            self.sidebar.select(path);
            return;
        }
        if (paths.kindOf(path) == null) {
            self.toast(c, "Cannot open that file type", .bad, 3);
            return;
        }
        self.enqueueOpen(path);
        self.sidebar.select(path);
        self.toast(c, c.print("opening {s}…", .{paths.basename(path)}), .busy, 1.5);
    }

    fn openPathNow(self: *App, path: []const u8) void {
        self.enqueueOpen(path);
        self.sidebar.select(path);
    }

    fn enqueueOpen(self: *App, path: []const u8) void {
        const pending: Pending = .{
            .kind = .open_doc,
            .tool = .extract,
            .path = self.gpa.dupe(u8, path) catch return,
        };
        self.queue.append(self.gpa, pending) catch {};
    }

    fn closeTab(self: *App, c: *ui.Context, index: usize) void {
        if (index >= self.tabs.items.len) return;
        const tab = self.tabs.items[index];
        if (tab.busy) {
            self.toast(c, "That tab is still working", .bad, 3);
            return;
        }
        _ = self.tabs.orderedRemove(index);
        if (self.active >= self.tabs.items.len and self.tabs.items.len > 0) self.active = self.tabs.items.len - 1;
        tab.deinit(self.gpa);
        c.changed = true;
    }

    fn makeTab(self: *App, doc: *model.Doc, path: []const u8) !*Tab {
        const tab = try self.gpa.create(Tab);
        errdefer self.gpa.destroy(tab);
        const kind = paths.kindOf(path) orelse .text;
        const save_path = if (kind == .text)
            try self.gpa.dupe(u8, path)
        else
            try paths.summaryFile(self.gpa, self.root, path);
        errdefer self.gpa.free(save_path);
        const placeholder = if (kind == .text)
            try self.gpa.dupe(u8, "This file's text.")
        else
            try std.fmt.allocPrint(self.gpa, "Summary of {s} — Ctrl+S saves it beside .revise/summaries/", .{paths.stem(path)});
        tab.* = .{
            .doc = doc,
            .path = try self.gpa.dupe(u8, path),
            .name = try self.gpa.dupe(u8, paths.basename(path)),
            .kind = kind,
            .save_path = save_path,
            .buffer = .{},
            .saved_text = try self.gpa.dupe(u8, ""),
            .placeholder = placeholder,
        };
        tab.reader.forget(self.gpa, doc.itemCount());
        return tab;
    }

    // --- the background jobs -----------------------------------------------

    fn enqueueIndex(self: *App) void {
        for (self.queue.items) |p| {
            if (p.kind == .index) return;
        }
        self.queue.append(self.gpa, .{ .kind = .index, .tool = .db }) catch {};
    }

    /// Files and links for quick open: asked once, and after a change.
    fn refreshLists(self: *App) void {
        self.queueSearchless(.files, .db);
        self.queueSearchless(.links, .db);
    }

    fn queueSearchless(self: *App, kind: PendingKind, tool: pybridge.Tool) void {
        for (self.queue.items) |p| {
            if (p.kind == kind) return;
        }
        self.queue.append(self.gpa, .{ .kind = kind, .tool = tool }) catch {};
    }

    fn enqueue(self: *App, pending: Pending) void {
        // Only one search is ever wanted: the newest.
        if (pending.kind == .search) {
            var i: usize = 0;
            while (i < self.queue.items.len) {
                if (self.queue.items[i].kind == .search) {
                    var old = self.queue.orderedRemove(i);
                    old.deinit(self.gpa);
                } else i += 1;
            }
        }
        self.queue.append(self.gpa, pending) catch {};
    }

    fn pump(self: *App, c: *ui.Context) void {
        if (self.runner.busy() or self.current != null) return;
        if (self.queue.items.len == 0) return;
        // Opening a document or saving goes before indexing: the index can
        // wait, the person cannot.
        var chosen: usize = 0;
        for (self.queue.items, 0..) |p, i| {
            if (p.kind != .index) {
                chosen = i;
                break;
            }
        }
        var pending = self.queue.orderedRemove(chosen);
        self.indexing = pending.kind == .index;
        const started = self.startJob(c, &pending);
        if (!started) {
            pending.deinit(self.gpa);
            return;
        }
        self.current = pending;
        c.frameIn(0.05);
    }

    fn startJob(self: *App, c: *ui.Context, p: *Pending) bool {
        const root = self.root;
        switch (p.kind) {
            .index => self.runner.start(.db, &.{ "index", "--root", root }) catch |err| {
                self.toast(c, c.print("index failed: {s}", .{@errorName(err)}), .bad, 3);
                return false;
            },
            .open_doc, .open_summary => self.runner.start(.extract, &.{ p.path, "--root", root }) catch return false,
            .save => {
                const tool: pybridge.Tool = if (p.tool == .save_text) .save_text else .save_docx;
                if (p.overwrite) {
                    self.runner.start(tool, &.{ "--root", root, "--path", p.path, "--markers", p.arg, "--overwrite" }) catch return false;
                } else {
                    self.runner.start(tool, &.{ "--root", root, "--path", p.path, "--markers", p.arg }) catch return false;
                }
                if (p.tab) |tab| {
                    tab.save_state = .working;
                    tab.busy = true;
                }
            },
            .highlights => self.runner.start(.db, &.{ "hl-list", "--root", root, "--path", p.path }) catch return false,
            .search => self.runner.start(.db, &.{ "search", "--root", root, p.arg }) catch return false,
            .files => self.runner.start(.db, &.{ "files", "--root", root }) catch return false,
            .links => self.runner.start(.db, &.{ "links", "--root", root }) catch return false,
            .new_file => self.runner.start(.new_file, &.{ "--root", root, "--path", p.path }) catch return false,
            .add_link => self.runner.start(.db, &.{ "link", "--root", root, "--path", p.path }) catch return false,
            .add_highlight => self.runner.start(.db, &.{ "hl-add", "--root", root, "--path", p.path, "--block", p.arg, "--text", p.extra }) catch return false,
        }
        return true;
    }

    fn pollJobs(self: *App, c: *ui.Context) void {
        while (self.runner.take()) |job| {
            if (self.current) |cur| {
                var pending = cur;
                self.current = null;
                self.handleJob(c, &pending, job);
                pending.deinit(self.gpa);
            }
            job.deinit();
        }
        if (self.runner.busy()) c.frameIn(0.05);
        self.pump(c);
        if (self.queue.items.len > 0) c.frameIn(0.05);
    }

    fn handleJob(self: *App, c: *ui.Context, p: *Pending, job: *pybridge.Job) void {
        if (job.spawn_error) |err| {
            self.failJob(c, p, c.print("cannot run Python: {s}", .{@errorName(err)}));
            return;
        }
        if (job.jsonError()) |e| {
            self.failJob(c, p, e);
            return;
        }
        if (p.kind == .save) self.indexing = false;
        switch (p.kind) {
            .index => {
                self.indexing = false;
                self.refreshLists();
                if (!job.exit_ok) self.toast(c, "index failed", .bad, 3);
            },
            .open_doc => self.finishOpen(c, p, job),
            .open_summary => {
                const tab = p.tab orelse return;
                if (tab.buffer.text().len > 0) return; // the person started typing
                const doc = model.parse(self.gpa, job.output(), tab.kind) catch return;
                defer doc.deinit(self.gpa);
                const text = doc.markerText(self.gpa) catch return;
                defer self.gpa.free(text);
                tab.buffer.set(text);
                self.gpa.free(tab.saved_text);
                tab.saved_text = self.gpa.dupe(u8, text) catch self.gpa.dupe(u8, "") catch return;
            },
            .save => self.finishSave(c, p, job),
            .highlights => {
                const tab = p.tab orelse return;
                const list = model.parseHighlights(self.gpa, job.output()) catch return;
                if (tab.highlights) |old| old.deinit(self.gpa);
                tab.highlights = list;
            },
            .search => {
                const results = model.parseSearch(self.gpa, job.output()) catch {
                    self.search_loading = false;
                    return;
                };
                if (self.search) |old| old.deinit(self.gpa);
                self.search = results;
                self.search_loading = false;
                self.overlay.index = 0;
            },
            .files => {
                self.files_loading = false;
                const list = model.parseFiles(self.gpa, job.output()) catch return;
                if (self.files) |old| old.deinit(self.gpa);
                self.files = list;
            },
            .links => {
                const list = model.parseLinks(self.gpa, job.output()) catch return;
                defer list.deinit(self.gpa);
                var links_buf: [256]sidebar.LinkView = undefined;
                const n = @min(list.items.len, links_buf.len);
                for (list.items[0..n], 0..) |item, i| {
                    links_buf[i] = .{ .alias = if (item.alias.len > 0) item.alias else paths.basename(item.path), .path = item.path };
                }
                self.sidebar.setLinked(links_buf[0..n]);
            },
            .new_file => {
                self.sidebar.reload(self.root);
                self.refreshLists();
                self.toast(c, c.print("created {s}", .{paths.basename(p.path)}), .good, 3);
                self.enqueueOpen(p.path);
            },
            .add_link => {
                self.refreshLists();
                self.enqueueIndex();
                self.toast(c, c.print("linked {s}", .{paths.basename(p.path)}), .good, 3);
            },
            .add_highlight => {
                if (p.tab) |tab| {
                    self.enqueue(.{ .kind = .highlights, .tool = .db, .tab = tab, .path = self.gpa.dupe(u8, tab.path) catch "" });
                }
                self.toast(c, "Highlighted", .good, 2);
            },
        }
    }

    fn failJob(self: *App, c: *ui.Context, p: *Pending, message: []const u8) void {
        if (p.kind == .index) self.indexing = false;
        if (p.tab) |tab| {
            tab.busy = false;
            if (p.kind == .save) {
                tab.save_state = .failed;
                if (tab.save_message.len > 0) self.gpa.free(tab.save_message);
                tab.save_message = self.gpa.dupe(u8, message) catch "";
            }
        }
        if (p.kind == .search) self.search_loading = false;
        self.toast(c, message, .bad, 4);
    }

    fn finishOpen(self: *App, c: *ui.Context, p: *Pending, job: *pybridge.Job) void {
        const kind = paths.kindOf(p.path) orelse return;
        const doc = model.parse(self.gpa, job.output(), kind) catch |err| {
            self.toast(c, c.print("cannot read {s}: {s}", .{ paths.basename(p.path), @errorName(err) }), .bad, 4);
            return;
        };
        // Already open? (two clicks before the first finished)
        if (self.tabByPath(p.path)) |i| {
            doc.deinit(self.gpa);
            self.active = i;
            return;
        }
        const tab = self.makeTab(doc, p.path) catch {
            doc.deinit(self.gpa);
            return;
        };
        self.tabs.append(self.gpa, tab) catch {
            tab.deinit(self.gpa);
            return;
        };
        self.active = self.tabs.items.len - 1;

        // The editor: a text file's own text, or the summary that already
        // exists for this document.
        if (tab.kind == .text) {
            const text = doc.markerText(self.gpa) catch "";
            defer if (text.len > 0) self.gpa.free(text);
            tab.buffer.set(text);
            self.gpa.free(tab.saved_text);
            tab.saved_text = self.gpa.dupe(u8, text) catch "";
        } else if (self.cachedSummaryText(tab.save_path)) |text| {
            defer self.gpa.free(text);
            tab.buffer.set(text);
            self.gpa.free(tab.saved_text);
            tab.saved_text = self.gpa.dupe(u8, text) catch "";
        } else if (fsops.exists(self.io, tab.save_path)) {
            self.enqueue(.{ .kind = .open_summary, .tool = .extract, .tab = tab, .path = self.gpa.dupe(u8, tab.save_path) catch "" });
        }
        self.enqueue(.{ .kind = .highlights, .tool = .db, .tab = tab, .path = self.gpa.dupe(u8, tab.path) catch "" });
        if (self.jump_after_open) |j| {
            if (std.mem.eql(u8, j.path, tab.path)) {
                tab.reader.goto_item = @min(@as(usize, j.page -| 1), tab.doc.itemCount() -| 1);
                self.gpa.free(j.path);
                self.jump_after_open = null;
            }
        }
        self.toast(c, c.print("opened {s}", .{tab.name}), .plain, 2);
    }

    /// The summary's text, if its cache still matches the file on disk.
    fn cachedSummaryText(self: *App, summary_path: []const u8) ?[]u8 {
        const st = fsops.statFile(self.io, summary_path) orelse return null;
        const cache = paths.cacheFile(self.gpa, self.root, summary_path, self.cwd) catch return null;
        defer self.gpa.free(cache);
        const bytes = fsops.readFile(self.gpa, self.io, cache) catch return null;
        defer self.gpa.free(bytes);
        const doc = model.parse(self.gpa, bytes, .docx) catch return null;
        defer doc.deinit(self.gpa);
        if (doc.source.size != st.size or doc.source.mtime != st.mtime) return null;
        return doc.markerText(self.gpa) catch null;
    }

    fn finishSave(self: *App, c: *ui.Context, p: *Pending, job: *pybridge.Job) void {
        const tab = p.tab orelse return;
        tab.busy = false;
        const reply = model.parseReply(self.gpa, job.output()) catch {
            if (self.debug_layout) {
                std.debug.print("save reply not parseable (exit_ok={}): {s}\n*** {s}\n", .{ job.exit_ok, job.output(), job.err_out });
            }
            self.saveFailed(c, tab, "the tool sent no answer");
            return;
        };
        defer reply.deinit(self.gpa);
        if (reply.conflict) {
            tab.save_state = .failed;
            self.setTabMessage(tab, "changed on disk");
            self.conflict_path = self.gpa.dupe(u8, p.path) catch "";
            self.overlay.message = "";
            overlays.open(self, .conflict);
            return;
        }
        if (reply.error_text.len > 0 or !reply.ok) {
            self.saveFailed(c, tab, if (reply.error_text.len > 0) reply.error_text else "save failed");
            return;
        }
        tab.save_state = .saved;
        self.setTabMessage(tab, "");
        self.gpa.free(tab.saved_text);
        tab.saved_text = self.gpa.dupe(u8, tab.buffer.text()) catch "";
        tab.dirty = false;
        tab.doc.source = reply.source;
        self.toast(c, c.print("{s} {s}", .{ if (reply.created) "created" else "saved", paths.basename(reply.path) }), .good, 3);
    }

    fn saveFailed(self: *App, c: *ui.Context, tab: *Tab, message: []const u8) void {
        tab.save_state = .failed;
        self.setTabMessage(tab, message);
        self.toast(c, message, .bad, 4);
    }

    fn setTabMessage(self: *App, tab: *Tab, message: []const u8) void {
        if (tab.save_message.len > 0) self.gpa.free(tab.save_message);
        tab.save_message = if (message.len > 0) self.gpa.dupe(u8, message) catch "" else "";
    }

    // --- actions the panes and overlays ask for -----------------------------

    pub fn saveActive(self: *App, c: *ui.Context) void {
        const tab = self.activeTab() orelse return;
        if (tab.busy) return;
        self.saveTab(c, tab, false);
    }

    fn saveTab(self: *App, c: *ui.Context, tab: *Tab, overwrite: bool) void {
        if (self.current) |cur| {
            if (cur.kind == .save) {
                self.toast(c, "a save is already running", .bad, 2);
                return;
            }
        }
        // The editor's text goes to a file the tool reads: no shell quoting,
        // no pipes, and the tool is the only writer of the source.
        const markers_file = paths.markersFile(self.gpa, self.root, self.counter) catch return;
        self.counter += 1;
        defer self.gpa.free(markers_file);
        const tmp_dir = paths.tmpDir(self.gpa, self.root) catch return;
        defer self.gpa.free(tmp_dir);
        fsops.makePath(self.io, tmp_dir) catch {};
        fsops.writeFile(self.io, markers_file, tab.buffer.text()) catch {
            self.saveFailed(c, tab, "cannot write the editor's text");
            return;
        };
        const tool: pybridge.Tool = if (tab.kind == .text) .save_text else .save_docx;
        tab.save_state = .working;
        self.indexing = false;
        self.enqueue(.{
            .kind = .save,
            .tool = tool,
            .tab = tab,
            .path = self.gpa.dupe(u8, tab.save_path) catch return,
            .arg = self.gpa.dupe(u8, markers_file) catch return,
            .overwrite = overwrite,
        });
        c.frameIn(0.05);
    }

    pub fn saveOverwrite(self: *App, c: *ui.Context) void {
        const tab = self.activeTab() orelse return;
        self.saveTab(c, tab, true);
    }

    /// "Save a copy" from the conflict dialog: a new summary file, and this
    /// tab keeps saving there.
    pub fn saveCopy(self: *App, c: *ui.Context) void {
        const tab = self.activeTab() orelse return;
        self.counter += 1;
        const dir = paths.summariesDir(self.gpa, self.root) catch return;
        defer self.gpa.free(dir);
        fsops.makePath(self.io, dir) catch {};
        const name = std.fmt.allocPrint(self.gpa, "{s}-summary-copy-{d}.docx", .{ paths.stem(tab.path), self.counter }) catch return;
        defer self.gpa.free(name);
        const copy = paths.join(self.gpa, &.{ dir, name }) catch return;
        self.gpa.free(tab.save_path);
        tab.save_path = copy;
        self.saveTab(c, tab, false);
    }

    pub fn boldSelection(self: *App, c: *ui.Context, tab: *Tab) void {
        self.wrapSelection(c, tab, markers.bold);
    }

    pub fn italicSelection(self: *App, c: *ui.Context, tab: *Tab) void {
        self.wrapSelection(c, tab, markers.italic);
    }

    fn wrapSelection(self: *App, c: *ui.Context, tab: *Tab, marker: []const u8) void {
        const text = tab.buffer.text();
        var lo = tab.editor.sel[0];
        var hi = tab.editor.sel[1];
        if (lo > hi) std.mem.swap(usize, &lo, &hi);
        const edit = markers.toggleWrap(self.gpa, text, lo, hi, marker) catch return;
        defer edit.deinit(self.gpa);
        tab.buffer.set(edit.text);
        tab.buffer.want_selection = edit.sel;
        tab.buffer.focus();
        tab.editor.sel = edit.sel;
        c.changed = true;
    }

    pub fn addToSummary(self: *App, c: *ui.Context, tab: *Tab, text: []const u8) void {
        const clean = std.mem.trim(u8, text, " \t\r\n");
        if (clean.len == 0) {
            self.toast(c, "Nothing to add: select text or click a block", .bad, 3);
            return;
        }
        const updated = markers.appendBullet(self.gpa, tab.buffer.text(), clean) catch return;
        defer self.gpa.free(updated);
        tab.buffer.set(updated);
        tab.buffer.focus();
        tab.save_state = .idle;
        c.changed = true;
        self.toast(c, "Added to the summary", .good, 2);
    }

    /// PDF highlights live in the database, never in the PDF: the block's id
    /// and the selected text are stored and drawn again on reload.
    pub fn highlightSelection(self: *App, c: *ui.Context, tab: *Tab, text: []const u8) void {
        const block = tab.reader.sel_block orelse {
            self.toast(c, "Click a block first, then Highlight", .bad, 3);
            return;
        };
        if (tab.kind != .pdf and tab.kind != .docx and tab.kind != .text) return;
        self.enqueue(.{
            .kind = .add_highlight,
            .tool = .db,
            .tab = tab,
            .path = self.gpa.dupe(u8, tab.path) catch "",
            .arg = self.gpa.dupe(u8, block) catch "",
            .extra = self.gpa.dupe(u8, std.mem.trim(u8, text, " \t\r\n")) catch "",
        });
        c.frameIn(0.05);
    }

    pub fn gotoPage(self: *App, c: *ui.Context, page: u32) void {
        _ = c;
        const tab = self.activeTab() orelse return;
        if (tab.doc.itemCount() == 0) return;
        const index: usize = if (tab.doc.isPaged())
            page -| 1
        else
            page -| 1;
        tab.reader.goto_item = @min(index, tab.doc.itemCount() - 1);
    }

    pub fn searchQuery(self: *App, c: *ui.Context, query: []const u8) void {
        const q = std.mem.trim(u8, query, " ");
        if (q.len < 2) return;
        if (std.mem.eql(u8, self.search_inflight, q)) return;
        if (self.search_inflight.len > 0) self.gpa.free(self.search_inflight);
        if (self.jump_after_open) |j| self.gpa.free(j.path);
        self.search_inflight = self.gpa.dupe(u8, q) catch "";
        self.search_loading = true;
        self.enqueue(.{ .kind = .search, .tool = .db, .arg = self.gpa.dupe(u8, q) catch "" });
        c.frameIn(0.05);
    }

    pub fn currentHit(self: *App) ?model.SearchHit {
        const results = self.search orelse return null;
        if (results.items.len == 0) return null;
        const i = @min(self.overlay.index, results.items.len - 1);
        return results.items[i];
    }

    pub fn openSearchHit(self: *App, c: *ui.Context, path: []const u8, page: u32) void {
        self.openPath(c, path);
        // The page is jumped to once the document is open, and the tab is
        // placed at it after extraction.
        self.jump_after_open = .{ .path = self.gpa.dupe(u8, path) catch "", .page = page };
    }

    pub fn addForeign(self: *App, c: *ui.Context, path: []const u8) void {
        const abs = paths.absoluteNorm(self.gpa, path, self.cwd) catch return;
        defer self.gpa.free(abs);
        if (!fsops.exists(self.io, abs)) {
            self.overlay.message = "No such file.";
            return;
        }
        self.enqueue(.{ .kind = .add_link, .tool = .db, .path = self.gpa.dupe(u8, abs) catch "" });
        self.toast(c, c.print("linking {s}…", .{paths.basename(abs)}), .busy, 2);
    }

    pub fn createFile(self: *App, c: *ui.Context, name: []const u8, kind_index: usize) void {
        const ext = switch (kind_index) {
            0 => ".md",
            1 => ".txt",
            else => ".docx",
        };
        const dir = self.targetDir();
        const file_name = std.fmt.allocPrint(self.gpa, "{s}{s}", .{ name, ext }) catch return;
        defer self.gpa.free(file_name);
        const path = paths.join(self.gpa, &.{ dir, file_name }) catch return;
        self.enqueue(.{ .kind = .new_file, .tool = .new_file, .path = path });
        self.toast(c, c.print("creating {s}…", .{file_name}), .busy, 2);
    }

    pub fn createFolder(self: *App, c: *ui.Context, name: []const u8) void {
        const dir = self.targetDir();
        const path = paths.join(self.gpa, &.{ dir, name }) catch return;
        defer self.gpa.free(path);
        fsops.makePath(self.io, path) catch {
            self.toast(c, "cannot create that folder", .bad, 3);
            return;
        };
        self.sidebar.reload(self.root);
        self.toast(c, c.print("created {s}/", .{name}), .good, 3);
    }

    fn targetDir(self: *App) []const u8 {
        if (self.sidebar.selected) |sel| {
            if (paths.kindOf(sel) == null) return sel;
            return paths.dirname(sel);
        }
        return self.root;
    }

    // --- keys ---------------------------------------------------------------

    fn shortcut(c: *ui.Context, text: []const u8) bool {
        const want = ui.Shortcut.parse(text) orelse return false;
        return c.shortcut(want);
    }

    fn handleShortcuts(self: *App, c: *ui.Context) void {
        const overlay_open = self.overlay.kind != .none;
        if (overlay_open) {
            if (c.input.key == .escape) {
                overlays.close(self);
                c.input.key = null;
                c.changed = true;
            }
            return;
        }
        if (c.input.key == .escape) {
            if (self.activeTab()) |tab| tab.reader.clearSelection(self.gpa);
            if (self.search) |s| {
                s.deinit(self.gpa);
                self.search = null;
            }
            c.input.key = null;
        }

        if (self.menu.open != null and c.input.key == .escape) {
            self.menu.close();
            c.input.key = null;
            c.changed = true;
            return;
        }
        if (shortcut(c, "cmd+s")) {
            self.saveActive(c);
            return;
        }
        if (shortcut(c, "cmd+b")) {
            if (self.activeTab()) |tab| self.boldSelection(c, tab);
            return;
        }
        if (shortcut(c, "cmd+i")) {
            if (self.activeTab()) |tab| self.italicSelection(c, tab);
            return;
        }
        if (shortcut(c, "cmd+q")) {
            if (self.win) |w| w.close();
            return;
        }
        if (shortcut(c, "cmd+shift+f")) {
            overlays.open(self, .search);
            return;
        }
        if (shortcut(c, "cmd+p")) {
            if (self.files == null) self.refreshLists();
            overlays.open(self, .quick_open);
            return;
        }
        if (shortcut(c, "cmd+g")) {
            overlays.open(self, .goto_page);
            return;
        }
        if (shortcut(c, "cmd+n")) {
            overlays.open(self, .new_file);
            return;
        }
        if (shortcut(c, "cmd+shift+n")) {
            overlays.open(self, .new_folder);
            return;
        }
        if (shortcut(c, "cmd+o")) {
            self.chooseFolder();
            return;
        }
        if (shortcut(c, "cmd+shift+d")) {
            self.dark = !self.dark;
            c.changed = true;
            return;
        }
        if (shortcut(c, "cmd+tab")) {
            self.nextTab(c, 1);
            return;
        }
        if (shortcut(c, "cmd+shift+tab")) {
            self.nextTab(c, -1);
            return;
        }
        if (shortcut(c, "cmd+w")) {
            self.closeTab(c, self.active);
            return;
        }
        if (shortcut(c, "cmd+=") or shortcut(c, "cmd+plus")) {
            self.setZoom(c, self.zoom_value + 0.1);
            return;
        }
        if (shortcut(c, "cmd+-")) {
            self.setZoom(c, self.zoom_value - 0.1);
            return;
        }
        if (shortcut(c, "cmd+0")) {
            self.setZoom(c, 1);
            return;
        }
        if (shortcut(c, "cmd+r")) {
            self.enqueueIndex();
            return;
        }
        // Page keys scroll the reader when the editor does not have the keys.
        if (!self.editor_focused) {
            const key = c.input.key orelse return;
            switch (key) {
                .page_up => {
                    self.scrollReader(c, -0.9);
                    c.input.key = null;
                },
                .page_down => {
                    self.scrollReader(c, 0.9);
                    c.input.key = null;
                },
                .home => {
                    if (self.activeTab()) |tab| tab.reader.goto_item = 0;
                    c.input.key = null;
                },
                .end => {
                    if (self.activeTab()) |tab| tab.reader.goto_item = tab.doc.itemCount() -| 1;
                    c.input.key = null;
                },
                else => {},
            }
        }
        // Ctrl+wheel zooms the reader.
        if (c.input.ctrl and c.input.scroll.y != 0) {
            self.setZoom(c, self.zoom_value + @as(f32, if (c.input.scroll.y > 0) 0.1 else -0.1));
        }
    }

    /// Runs a command from the menu bar (or from a key that shares its work).
    fn runCommand(self: *App, c: *ui.Context, cmd: menu_bar.Command) void {
        switch (cmd) {
            .new_file => overlays.open(self, .new_file),
            .new_folder => overlays.open(self, .new_folder),
            .open_folder => self.chooseFolder(),
            .add_foreign => overlays.open(self, .add_foreign),
            .quit => {
                if (self.win) |w| w.close();
            },
            .save => self.saveActive(c),
            .bold => if (self.activeTab()) |tab| self.boldSelection(c, tab),
            .italic => if (self.activeTab()) |tab| self.italicSelection(c, tab),
            .heading => if (self.activeTab()) |tab| self.headingLine(c, tab),
            .bullet => if (self.activeTab()) |tab| self.bulletLine(c, tab),
            .add_to_summary => {
                if (self.activeTab()) |tab| {
                    const text = tab.reader.sel_text orelse "";
                    self.addToSummary(c, tab, text);
                }
            },
            .zoom_in => self.setZoom(c, self.zoom_value + 0.1),
            .zoom_out => self.setZoom(c, self.zoom_value - 0.1),
            .zoom_reset => self.setZoom(c, 1),
            .theme => {
                self.dark = !self.dark;
                c.changed = true;
            },
            .reindex => self.enqueueIndex(),
            .search_all => overlays.open(self, .search),
            .quick_open => {
                if (self.files == null) self.refreshLists();
                overlays.open(self, .quick_open);
            },
            .goto_page => overlays.open(self, .goto_page),
            .next_tab => self.nextTab(c, 1),
            .close_tab => self.closeTab(c, self.active),
            .shortcuts => overlays.open(self, .shortcuts),
            .about => self.toast(c, "revise 0.1.0 — a reader for PDF and Word revision notes", .plain, 5),
        }
        c.changed = true;
    }

    pub fn headingLine(self: *App, c: *ui.Context, tab: *Tab) void {
        self.linePrefix(c, tab, markers.headingPrefix(2));
    }

    pub fn bulletLine(self: *App, c: *ui.Context, tab: *Tab) void {
        self.linePrefix(c, tab, markers.bullet);
    }

    fn linePrefix(self: *App, c: *ui.Context, tab: *Tab, prefix: []const u8) void {
        const edit = markers.toggleLinePrefix(self.gpa, tab.buffer.text(), tab.editor.sel[1], prefix) catch return;
        defer edit.deinit(self.gpa);
        tab.buffer.set(edit.text);
        tab.buffer.want_selection = edit.sel;
        tab.buffer.focus();
        tab.editor.sel = edit.sel;
        c.changed = true;
    }

    fn setZoom(self: *App, c: *ui.Context, zoom: f32) void {
        const next = std.math.clamp(zoom, 0.6, 2.4);
        if (next == self.zoom_value) return;
        self.zoom_value = next;
        if (self.activeTab()) |tab| tab.reader.forget(self.gpa, tab.doc.itemCount());
        c.changed = true;
    }

    fn nextTab(self: *App, c: *ui.Context, step: i32) void {
        if (self.tabs.items.len < 2) return;
        const n: i32 = @intCast(self.tabs.items.len);
        const now: i32 = @intCast(self.active);
        self.active = @intCast(@mod(now + step, n));
        c.changed = true;
    }

    fn scrollReader(self: *App, c: *ui.Context, pages: f32) void {
        const tab = self.activeTab() orelse return;
        const view_h = tab.reader.view_h;
        const target = tab.reader.scroll_off + view_h * pages;
        c.setScroll(tab.reader.scroll_id, .y, @max(0, target));
        c.changed = true;
    }

    fn chooseFolder(self: *App) void {
        const gpa = self.gpa;
        const picked = nanoui.dialog.open(gpa, .{
            .title = "Open a folder",
            .button = "Open",
            .files = true,
            .directories = true,
        }) catch return;
        const list = picked orelse return;
        defer nanoui.dialog.freePaths(gpa, list);
        if (list.len == 0) return;
        const chosen = list[0];
        // A file picker that cannot choose folders still gets us close: use
        // the file's folder.
        if (paths.kindOf(chosen) != null) {
            const dir = paths.dirname(chosen);
            if (dir.len > 0) self.setRoot(dir);
        } else {
            self.setRoot(chosen);
        }
    }

    pub fn setZoomPublic(self: *App, c: *ui.Context, zoom: f32) void {
        self.setZoom(c, zoom);
    }
};

test "tab names and summaries" {
    const a = std.testing.allocator;
    const summary = try paths.summaryFile(a, "/root", "/root/exams/biology.docx");
    defer a.free(summary);
    try std.testing.expectEqualStrings("/root/.revise/summaries/biology-summary.docx", summary);
}

/// The tab strip's file-type letter, as the sidebar's glyphs have it.
fn glyphFor(kind: paths.Kind) []const u8 {
    return switch (kind) {
        .pdf => "P",
        .docx => "D",
        .text => "T",
    };
}
