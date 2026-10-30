//! The dialogs drawn over the page: global search (Ctrl+Shift+F), quick open
//! (Ctrl+P), add a foreign file, the save-conflict question, new file, new
//! folder and go-to-page. Each is a flat panel with a text field and buttons;
//! Escape closes them all.
const std = @import("std");
const ui = @import("nanoui").ui;
const nanoui = @import("nanoui");
const model = @import("model.zig");
const paths = @import("paths.zig");
const theme = @import("theme.zig");

pub const Kind = enum { none, search, quick_open, add_foreign, conflict, new_file, new_folder, goto_page, shortcuts };

pub const State = struct {
    kind: Kind = .none,
    /// The panel's text field.
    input: ui.TextBuffer = .{},
    /// Selection in a list of results or files.
    index: usize = 0,
    /// New file: 0 md, 1 txt, 2 docx.
    file_kind: usize = 0,
    /// The last query sent, so a text field is not re-fired every frame.
    last_query: []const u8 = "",
    /// The dialog's error line.
    message: []const u8 = "",
    pub fn deinit(self: *State) void {
        self.input.deinit();
    }
};

pub fn open(app: anytype, kind: Kind) void {
    app.overlay.kind = kind;
    app.overlay.input.clear();
    app.overlay.index = 0;
    app.overlay.message = "";
    app.overlay.input.focus();
}

pub fn close(app: anytype) void {
    if (app.overlay.kind == .search) {
        if (app.search) |s| {
            s.deinit(app.gpa);
            app.search = null;
        }
    }
    app.overlay.kind = .none;
    app.overlay.input.clear();
    app.overlay.message = "";
}

pub fn view(app: anytype, c: *ui.Context) void {
    if (app.overlay.kind == .none) return;
    const th = c.theme;
    // A scrim, so the page behind is clearly inactive.
    _ = c.leaf(.{
        .absolute = true,
        .fixed = true,
        .layer = 1,
        .width = .fill,
        .height = .fill,
        .background = th.background.alpha(0.62),
    }, .none, "scrim");
    switch (app.overlay.kind) {
        .none => {},
        .search => searchView(app, c),
        .quick_open => quickOpenView(app, c),
        .add_foreign => addForeignView(app, c),
        .conflict => conflictView(app, c),
        .new_file => newFileView(app, c),
        .new_folder => newFolderView(app, c),
        .goto_page => gotoPageView(app, c),
        .shortcuts => shortcutsView(app, c),
    }
}

fn panelWidth(c: *ui.Context, want: f32) f32 {
    return @min(want, c.size.w - 40);
}

fn panel(app: anytype, c: *ui.Context, title: []const u8, width: f32) void {
    _ = app;
    const th = c.theme;
    const w = panelWidth(c, width);
    ui.column(c, .{
        .absolute = true,
        .fixed = true,
        .layer = 2,
        .width = .{ .px = w },
        .offset = .{ .x = (c.size.w - w) / 2, .y = 56 },
        .padding = .all(14),
        .gap = 10,
        .background = th.surface,
        .border = th.border,
        .max_height = c.size.h - 120,
    });
    ui.row(c, .{ .width = .fill, .align_items = .center });
    ui.text(c, title, .{ .size = 13, .weight = .semibold, .color = th.text });
    ui.spacer(c);
    ui.kbd(c, "Esc");
    ui.end(c);
}

fn errorLine(c: *ui.Context, app: anytype) void {
    if (app.overlay.message.len == 0) return;
    ui.text(c, app.overlay.message, .{ .size = 11.5, .color = c.theme.danger, .wrap = true });
}

// --- search ----------------------------------------------------------------

fn searchView(app: anytype, c: *ui.Context) void {
    const th = c.theme;
    panel(app, c, "Search all files", 640);
    const result = ui.textField(c, &app.overlay.input, .{
        .placeholder = "Search PDFs, DOCX and notes…",
        .width = .fill,
        .size = 13,
        .bare = false,
        .color = th.text,
    });
    if (result.changed and app.overlay.input.text().len >= 2) {
        app.searchQuery(c, app.overlay.input.text());
    }
    if (result.submitted) {
        if (app.currentHit()) |hit| app.openSearchHit(c, hit.path, hit.page);
        close(app);
        ui.end(c);
        return;
    }
    if (c.input.key == .up) {
        if (app.overlay.index > 0) app.overlay.index -= 1;
    } else if (c.input.key == .down) {
        if (app.search) |s| {
            if (app.overlay.index + 1 < s.items.len) app.overlay.index += 1;
        }
    }

    if (app.search_loading and app.search == null) {
        ui.text(c, "searching…", .{ .size = 12, .color = th.muted });
    } else if (app.search) |s| {
        if (s.items.len == 0) {
            ui.text(c, if (s.query.len == 0) "Type to search everything in the folder and its links." else "No matches.", .{ .size = 12, .color = th.muted });
        } else {
            ui.row(c, .{ .width = .fill, .height = .{ .px = 20 }, .align_items = .center });
            const files_n = blk: {
                var n: usize = 0;
                var last: []const u8 = "";
                for (s.items) |hit| {
                    if (!std.mem.eql(u8, hit.path, last)) {
                        last = hit.path;
                        n += 1;
                    }
                }
                break :blk n;
            };
            ui.text(c, c.print("{d} results across {d} {s}", .{ s.items.len, files_n, if (files_n == 1) "file" else "files" }), .{ .size = 11, .color = th.muted });
            ui.spacer(c);
            ui.text(c, "↑ ↓ navigate   Enter to open", .{ .size = 10.5, .color = th.muted.alpha(0.8) });
            ui.end(c);
            const list_h = @min(360, c.size.h - 240);
            ui.scroll(c, .{ .width = .fill, .height = .{ .px = list_h }, .gap = 2 });
            var last_path: []const u8 = "";
            for (s.items, 0..) |hit, i| {
                if (!std.mem.eql(u8, hit.path, last_path)) {
                    last_path = hit.path;
                    ui.row(c, .{ .width = .fill, .height = .{ .px = 24 }, .align_items = .center, .padding = .{ .left = 4 }, .gap = 6 });
                    ui.text(c, glyphFor(hit.kind), .{ .size = 10, .mono = true, .color = th.muted });
                    ui.text(c, paths.basename(hit.path), .{ .size = 11.5, .weight = .semibold, .color = th.text });
                    ui.text(c, paths.dirname(hit.path), .{ .size = 10.5, .color = th.muted.alpha(0.8), .truncate = .middle });
                    ui.spacer(c);
                    ui.end(c);
                }
                const selected = i == app.overlay.index;
                ui.keyInt(c, i);
                const row = ui.pressable(c, .{
                    .direction = .column,
                    .width = .fill,
                    .padding = .xy(6, 4),
                    .gap = 1,
                    .background = if (selected) th.accent.alpha(0.14) else null,
                    .control = true,
                }, th.surface_hover);
                // The snippet, with the term in the accent.
                // Python counts characters; drawing needs bytes.
                const lo = @import("markers.zig").cpToByte(hit.snippet, hit.hit[0]);
                const hi = @import("markers.zig").cpToByte(hit.snippet, hit.hit[1]);
                // The spans outlive this call (the frame draws them after the
                // view returns), so they live in the frame's own memory.
                if (c.alloc().alloc(ui.Span, 1)) |spans| {
                    spans[0] = .{
                        .start = @intCast(lo),
                        .end = @intCast(@max(hi, lo)),
                        .color = th.text,
                        .background = theme.highlightColor(th.dark).alpha(0.30),
                    };
                    ui.richText(c, hit.snippet, spans, .{ .size = 12, .color = th.muted, .wrap = true });
                } else |_| {
                    ui.text(c, hit.snippet, .{ .size = 12, .color = th.muted, .wrap = true });
                }
                ui.row(c, .{ .width = .fill });
                const where = if (std.mem.eql(u8, hit.kind, "pdf"))
                    c.print("p. {d}", .{hit.page})
                else if (std.mem.eql(u8, hit.kind, "docx"))
                    c.print("¶ {d}", .{hit.page})
                else
                    c.print("Ln {d}", .{hit.page});
                ui.text(c, where, .{ .size = 10.5, .color = th.muted.alpha(0.85), .tabular = true });
                ui.end(c);
                ui.end(c);
                if (row.clicked) {
                    app.openSearchHit(c, hit.path, hit.page);
                    close(app);
                }
            }
            ui.end(c);
        }
    } else {
        ui.text(c, "Type at least two characters.", .{ .size = 12, .color = th.muted });
    }
    errorLine(c, app);
    ui.end(c);
}

// --- quick open ------------------------------------------------------------

fn quickOpenView(app: anytype, c: *ui.Context) void {
    const th = c.theme;
    panel(app, c, "Open a file", 560);
    const result = ui.textField(c, &app.overlay.input, .{
        .placeholder = "Type part of a file name…",
        .width = .fill,
        .size = 13,
        .bare = false,
        .color = th.text,
    });
    const query = app.overlay.input.text();
    var shown: usize = 0;
    var matches: [200][]const u8 = undefined;
    if (app.files) |files| {
        for (files.items) |f| {
            if (shown >= matches.len) break;
            if (query.len == 0 or fuzzyMatch(paths.basename(f.path), query) != null) {
                matches[shown] = f.path;
                shown += 1;
            }
        }
    }
    if (app.overlay.index >= shown and shown > 0) app.overlay.index = shown - 1;
    if (c.input.key == .up) {
        if (app.overlay.index > 0) app.overlay.index -= 1;
    } else if (c.input.key == .down) {
        if (app.overlay.index + 1 < shown) app.overlay.index += 1;
    }
    if (result.submitted and shown > 0) {
        const chosen = matches[app.overlay.index];
        close(app);
        app.openPath(c, chosen);
        ui.end(c);
        return;
    }
    if (shown == 0) {
        ui.text(c, if (app.files == null) "Reading the file list…" else "No file matches.", .{ .size = 12, .color = th.muted });
    } else {
        const list_h = @max(60, @min(320, c.size.h - 260));
        ui.scroll(c, .{ .width = .fill, .height = .{ .px = list_h }, .gap = 1 });
        var i: usize = 0;
        while (i < shown) : (i += 1) {
            const path = matches[i];
            const selected = i == app.overlay.index;
            ui.keyInt(c, i);
            const row = ui.pressable(c, .{
                .direction = .row,
                .width = .fill,
                .height = .{ .px = 26 },
                .align_items = .center,
                .padding = .xy(6, 0),
                .gap = 8,
                .background = if (selected) th.accent.alpha(0.14) else null,
                .control = true,
            }, th.surface_hover);
            ui.text(c, paths.basename(path), .{ .size = 12.5, .color = th.text, .truncate = .ellipsis });
            ui.spacer(c);
            ui.text(c, paths.dirname(path), .{ .size = 10.5, .color = th.muted.alpha(0.8), .truncate = .middle });
            ui.end(c);
            if (row.clicked) {
                close(app);
                app.openPath(c, path);
                ui.end(c);
                return;
            }
        }
        ui.end(c);
    }
    errorLine(c, app);
    ui.end(c);
}

// --- add a foreign file ----------------------------------------------------

fn addForeignView(app: anytype, c: *ui.Context) void {
    const th = c.theme;
    panel(app, c, "Add foreign file", 560);
    ui.text(c, "Link a file from anywhere on this PC.", .{ .size = 12, .color = th.muted });
    ui.text(c, "File path", .{ .size = 11, .weight = .medium, .color = th.text });
    ui.row(c, .{ .width = .fill, .gap = 8, .align_items = .center });
    const result = ui.textField(c, &app.overlay.input, .{
        .placeholder = "/path/to/notes.pdf",
        .width = .fill,
        .size = 13,
        .bare = false,
        .color = th.text,
    });
    if (ui.button(c, "Browse…", .{ .variant = .secondary, .size = 12 }).clicked) {
        if (browseForFile(app)) |p| app.overlay.input.set(p);
    }
    ui.end(c);
    ui.row(c, .{ .width = .fill, .gap = 8, .align_items = .center });
    if (ui.button(c, "Link into current folder", .{ .variant = .primary, .size = 12 }).clicked or result.submitted) {
        const text = app.overlay.input.text();
        if (text.len == 0) {
            app.overlay.message = "Give the file's path.";
        } else {
            app.addForeign(c, text);
            close(app);
        }
    }
    if (ui.button(c, "Cancel", .{ .variant = .secondary, .size = 12 }).clicked) close(app);
    ui.end(c);
    ui.text(c, "The file stays where it is.", .{ .size = 11.5, .color = th.muted, .italic = true });
    errorLine(c, app);
    ui.end(c);
}

fn browseForFile(app: anytype) ?[]const u8 {
    const picked = nanoui.dialog.open(app.gpa, .{
        .title = "Choose a file to link",
        .button = "Link",
        .files = true,
        .directories = false,
    }) catch return null;
    const paths_out = picked orelse return null;
    defer nanoui.dialog.freePaths(app.gpa, paths_out);
    if (paths_out.len == 0) return null;
    const copy = app.arena.allocator().dupe(u8, paths_out[0]) catch return null;
    return copy;
}

// --- save conflict ---------------------------------------------------------

fn conflictView(app: anytype, c: *ui.Context) void {
    const th = c.theme;
    panel(app, c, "Source file changed outside the app.", 520);
    const name = if (app.conflict_path.len > 0) paths.basename(app.conflict_path) else "The file";
    ui.text(c, c.print("{s} has newer changes on disk, so nothing was written.", .{name}), .{
        .size = 12,
        .color = th.text,
        .wrap = true,
    });
    if (app.conflict_path.len > 0) {
        ui.text(c, app.conflict_path, .{ .size = 11, .color = th.muted, .wrap = true });
    }
    ui.spacer(c);
    ui.row(c, .{ .width = .fill, .gap = 8, .justify = .end });
    if (ui.button(c, "Overwrite", .{ .variant = .secondary, .size = 12 }).clicked) {
        close(app);
        app.saveOverwrite(c);
    }
    if (ui.button(c, "Save a copy", .{ .variant = .secondary, .size = 12 }).clicked) {
        close(app);
        app.saveCopy(c);
    }
    if (ui.button(c, "Cancel", .{ .variant = .primary, .size = 12 }).clicked) close(app);
    ui.end(c);
    errorLine(c, app);
    ui.end(c);
}

// --- new file / folder -----------------------------------------------------

fn newFileView(app: anytype, c: *ui.Context) void {
    const th = c.theme;
    panel(app, c, "New file", 480);
    ui.text(c, c.print("In {s}", .{app.target_dir}), .{ .size = 11, .color = th.muted, .truncate = .middle });
    const result = ui.textField(c, &app.overlay.input, .{
        .placeholder = "cellular-respiration",
        .width = .fill,
        .size = 13,
        .bare = false,
        .color = th.text,
    });
    _ = ui.segmented(c, &.{ "md", "txt", "docx" }, &app.overlay.file_kind);
    ui.row(c, .{ .width = .fill, .gap = 8, .justify = .end });
    if (ui.button(c, "Cancel", .{ .variant = .ghost, .size = 12 }).clicked) close(app);
    if (ui.button(c, "Create", .{ .variant = .primary, .size = 12 }).clicked or result.submitted) {
        const name = app.overlay.input.text();
        if (!validName(name)) {
            app.overlay.message = "Use a name without slashes.";
        } else {
            app.createFile(c, name, app.overlay.file_kind);
            close(app);
        }
    }
    ui.end(c);
    errorLine(c, app);
    ui.end(c);
}

fn newFolderView(app: anytype, c: *ui.Context) void {
    const th = c.theme;
    panel(app, c, "New folder", 480);
    ui.text(c, c.print("In {s}", .{app.target_dir}), .{ .size = 11, .color = th.muted, .truncate = .middle });
    const result = ui.textField(c, &app.overlay.input, .{
        .placeholder = "Exams",
        .width = .fill,
        .size = 13,
        .bare = false,
        .color = th.text,
    });
    ui.row(c, .{ .width = .fill, .gap = 8, .justify = .end });
    if (ui.button(c, "Cancel", .{ .variant = .ghost, .size = 12 }).clicked) close(app);
    if (ui.button(c, "Create", .{ .variant = .primary, .size = 12 }).clicked or result.submitted) {
        const name = app.overlay.input.text();
        if (!validName(name)) {
            app.overlay.message = "Use a name without slashes.";
        } else {
            app.createFolder(c, name);
            close(app);
        }
    }
    ui.end(c);
    errorLine(c, app);
    ui.end(c);
}

// --- go to page ------------------------------------------------------------

fn gotoPageView(app: anytype, c: *ui.Context) void {
    const th = c.theme;
    panel(app, c, "Go to page", 360);
    const result = ui.textField(c, &app.overlay.input, .{
        .placeholder = "12",
        .width = .fill,
        .size = 13,
        .bare = false,
        .color = th.text,
    });
    ui.row(c, .{ .width = .fill, .gap = 8, .justify = .end });
    if (ui.button(c, "Cancel", .{ .variant = .ghost, .size = 12 }).clicked) close(app);
    if (ui.button(c, "Go", .{ .variant = .primary, .size = 12 }).clicked or result.submitted) {
        const n = std.fmt.parseInt(u32, std.mem.trim(u8, app.overlay.input.text(), " "), 10) catch 0;
        if (n == 0) {
            app.overlay.message = "Type a page number.";
        } else {
            close(app);
            app.gotoPage(c, n);
        }
    }
    ui.end(c);
    errorLine(c, app);
    ui.end(c);
}

// --- keyboard shortcuts ----------------------------------------------------

const keys = [_]struct { []const u8, []const u8 }{
    .{ "Ctrl+P", "Open a file by name" },
    .{ "Ctrl+Shift+F", "Search every indexed file" },
    .{ "Ctrl+G", "Go to a page" },
    .{ "Ctrl+S", "Save the summary" },
    .{ "Ctrl+B / Ctrl+I", "Bold or italic the selection" },
    .{ "Ctrl+N / Ctrl+Shift+N", "New file / new folder" },
    .{ "Ctrl+O", "Open a folder" },
    .{ "Ctrl+Tab", "Next tab" },
    .{ "Ctrl+W", "Close the tab" },
    .{ "Ctrl+= / Ctrl+- / Ctrl+0", "Zoom the reader" },
    .{ "Ctrl+Shift+D", "Light or dark theme" },
    .{ "Ctrl+R", "Index the folder again" },
    .{ "PgUp / PgDn", "A screen up or down" },
    .{ "Home / End", "First or last page" },
    .{ "Esc", "Close a dialog, drop the selection" },
};

fn shortcutsView(app: anytype, c: *ui.Context) void {
    const th = c.theme;
    panel(app, c, "Keyboard shortcuts", 520);
    for (keys) |k| {
        ui.row(c, .{ .width = .fill, .height = .{ .px = 22 }, .align_items = .center, .gap = 12 });
        _ = c.open(.{ .width = .{ .px = 190 }, .align_items = .center }, "key");
        ui.text(c, k[0], .{ .size = 11.5, .color = th.text, .mono = true });
        ui.end(c);
        ui.text(c, k[1], .{ .size = 11.5, .color = th.muted });
        ui.end(c);
    }
    ui.row(c, .{ .width = .fill, .gap = 8, .justify = .end });
    if (ui.button(c, "Close", .{ .variant = .primary, .size = 12 }).clicked) close(app);
    ui.end(c);
    ui.end(c);
}

// --- helpers ---------------------------------------------------------------

/// A file name: something, no separators.
pub fn validName(name: []const u8) bool {
    const trimmed = std.mem.trim(u8, name, " ");
    if (trimmed.len == 0 or trimmed.len > 120) return false;
    if (std.mem.indexOfAny(u8, trimmed, "/\\:*?\"<>|") != null) return false;
    // No hidden files and no names that a command line would read as flags.
    if (trimmed[0] == '.' or trimmed[0] == '-') return false;
    return true;
}

/// A case-insensitive subsequence match: what quick open and fuzzy filters
/// use. Returns the number of characters skipped (lower is better), or null.
pub fn fuzzyMatch(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    var h: usize = 0;
    var n: usize = 0;
    var skipped: usize = 0;
    while (h < haystack.len and n < needle.len) : (h += 1) {
        if (std.ascii.toLower(haystack[h]) == std.ascii.toLower(needle[n])) {
            n += 1;
        } else {
            skipped += 1;
        }
    }
    if (n < needle.len) return null;
    return skipped;
}

/// The file-type letter a search result's heading shows.
fn glyphFor(kind: []const u8) []const u8 {
    if (std.mem.eql(u8, kind, "pdf")) return "P";
    if (std.mem.eql(u8, kind, "docx")) return "D";
    return "T";
}

/// A marker text's longest visible line, for the hint under a summary.
pub fn isDocumentKind(kind: paths.Kind) bool {
    return kind == .pdf or kind == .docx or kind == .text;
}

test "file names" {
    try std.testing.expect(validName("biology"));
    try std.testing.expect(validName("past paper 2019"));
    try std.testing.expect(!validName(""));
    try std.testing.expect(!validName("   "));
    try std.testing.expect(!validName("a/b"));
    try std.testing.expect(!validName(".."));
    try std.testing.expect(!validName(".hidden"));
}

test "fuzzy matching" {
    try std.testing.expectEqual(@as(?usize, 0), fuzzyMatch("biology", ""));
    try std.testing.expect(fuzzyMatch("biology", "bio") != null);
    try std.testing.expect(fuzzyMatch("biology", "BIO") != null);
    try std.testing.expect(fuzzyMatch("biology", "bgy") != null);
    try std.testing.expectEqual(@as(?usize, null), fuzzyMatch("biology", "xyz"));
    try std.testing.expectEqual(@as(?usize, null), fuzzyMatch("bio", "biology"));
    // Closer matches score better.
    try std.testing.expect(fuzzyMatch("biology", "bi").? < fuzzyMatch("biology", "gy").?);
}
