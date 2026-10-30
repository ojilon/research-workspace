//! The top pane: a PDF as flowing text pages with a thin ruler between them,
//! or a DOCX/Markdown/text document as paragraphs. Only the pages around the
//! one being read are built (about ±2), with spacers standing in for the
//! rest, so a 300-page PDF costs what three pages do.
const std = @import("std");
const ui = @import("nanoui").ui;
const model = @import("model.zig");
const paths = @import("paths.zig");
const theme = @import("theme.zig");

/// What a page or paragraph is assumed to be tall before it is measured.
const pdf_estimate: f32 = 780;
const para_estimate: f32 = 56;
/// How far past the visible page the reader builds.
const window_pages: usize = 2;

/// How wide the text may get: a line of prose, not a wall of it.
pub const measure: f32 = 880;
const ruler_height: f32 = 26;
const page_gap: f32 = 18;

pub const State = struct {
    /// Measured heights, by item. 0 means "not measured yet".
    heights: std.ArrayList(f32) = .empty,
    measured_zoom: f32 = 0,
    measured_width: f32 = 0,
    /// The item at the top of the view, and the box that scrolls it.
    item: usize = 0,
    scroll_id: u64 = 0,
    view_h: f32 = 0,
    scroll_off: f32 = 0,
    /// An item to scroll to next frame.
    goto_item: ?usize = null,
    /// How many frames the jump has been re-applied: the item heights are
    /// measured as it happens, so the offset is only right after a few.
    jump_frames: u8 = 0,
    /// The block clicked last (its id and text), for Highlight and Add to
    /// summary when nothing is selected.
    sel_block: ?[]u8 = null,
    sel_text: ?[]u8 = null,
    /// Where that block was drawn, so a toolbar can sit under it.
    sel_rect: ?ui.Rect = null,

    pub fn deinit(self: *State, gpa: std.mem.Allocator) void {
        self.heights.deinit(gpa);
        if (self.sel_block) |s| gpa.free(s);
        if (self.sel_text) |s| gpa.free(s);
        self.* = undefined;
    }

    pub fn selectBlock(self: *State, gpa: std.mem.Allocator, id: []const u8, text: []const u8) void {
        if (self.sel_block) |s| gpa.free(s);
        if (self.sel_text) |s| gpa.free(s);
        self.sel_block = gpa.dupe(u8, id) catch null;
        self.sel_text = gpa.dupe(u8, text) catch null;
    }

    pub fn clearSelection(self: *State, gpa: std.mem.Allocator) void {
        if (self.sel_block) |s| gpa.free(s);
        if (self.sel_text) |s| gpa.free(s);
        self.sel_block = null;
        self.sel_text = null;
    }

    /// Forgets measured heights: they belong to a zoom level and a width.
    pub fn forget(self: *State, gpa: std.mem.Allocator, count: usize) void {
        self.heights.clearRetainingCapacity();
        self.heights.resize(gpa, count) catch return;
        @memset(self.heights.items, 0);
    }
};

/// The height assumed for item `i` until it has been measured.
pub fn heightFor(st: *const State, i: usize, paged: bool) f32 {
    if (i < st.heights.items.len) {
        const h = st.heights.items[i];
        if (h > 0) return h;
    }
    return if (paged) pdf_estimate else para_estimate;
}

/// The top of item `i` in the scrolling column.
pub fn offsetOf(st: *const State, i: usize, paged: bool) f32 {
    var y: f32 = 0;
    var k: usize = 0;
    while (k < i) : (k += 1) {
        y += heightFor(st, k, paged);
        if (paged) y += page_gap + ruler_height;
    }
    return y;
}

/// The item at `offset`, for the page number in the status bar.
pub fn itemAt(st: *const State, offset: f32, count: usize, paged: bool) usize {
    var y: f32 = 0;
    var k: usize = 0;
    while (k < count) : (k += 1) {
        const h = heightFor(st, k, paged);
        if (offset < y + h) return k;
        y += h;
        if (paged) y += page_gap + ruler_height;
    }
    return if (count > 0) count - 1 else 0;
}

/// The starting item for a page of scrolling: the page the top of the view
/// is on.
pub fn firstVisible(st: *const State, offset: f32, count: usize, paged: bool) usize {
    return itemAt(st, @max(0, offset), count, paged);
}

pub fn view(app: anytype, c: *ui.Context, tab: anytype, grow: f32) void {
    const th = c.theme;
    const doc = tab.doc;
    ui.key(c, "reader-scroll");
    const scroll_id = c.peekId(null);
    tab.reader.scroll_id = scroll_id;

    const count = doc.itemCount();
    const paged = doc.isPaged();

    // Height `.fill` as well as grow: a measured height would be counted as
    // "used" by the parent, and the editor would take the rest of the window.
    ui.scroll(c, .{
        .width = .fill,
        .height = .fill,
        .grow = grow,
        .background = th.background,
        .padding = .{ .left = 20, .right = 20, .top = 14, .bottom = 20 },
        .gap = 0,
        .selectable = true,
    });
    if (count == 0) {
        emptyState(c, doc);
        ui.end(c);
        return;
    }

    // A jump asked for by a key or the go-to-page overlay. It is applied
    // again for a few frames: the pages it passes are measured on the way,
    // and their heights are what the offset is made of.
    if (tab.reader.goto_item) |target| {
        const clamped = @min(target, count - 1);
        c.setScroll(scroll_id, .y, offsetOf(&tab.reader, clamped, paged));
        tab.reader.item = clamped;
        tab.reader.jump_frames += 1;
        if (tab.reader.jump_frames >= 3) {
            tab.reader.goto_item = null;
            tab.reader.jump_frames = 0;
        }
        c.frameIn(0.02);
    }

    const view_h: f32 = if (c.rects.get(scroll_id)) |r| r.h else c.size.h * 0.4;
    tab.reader.view_h = view_h;
    const off = c.scroll.get(scroll_id) orelse 0;
    tab.reader.scroll_off = off;

    const first = firstVisible(&tab.reader, off, count, paged);
    tab.reader.item = first;
    const last = @min(count, first + 1 + window_pages * 2);
    const before = @max(first -| window_pages, 0);

    // A reading column, as the design has it: the text keeps a comfortable
    // measure on a wide window instead of running the full width.
    ui.column(c, .{ .width = .fill, .align_items = .center, .gap = 0 });
    ui.column(c, .{ .width = .fill, .max_width = measure, .gap = 0 });

    // The room taken by what is above the window.
    if (before > 0) {
        _ = c.leaf(.{ .width = .fill, .height = .{ .px = offsetOf(&tab.reader, before, paged) } }, .none, "reader-before");
    }

    var i = before;
    while (i < last) : (i += 1) {
        if (paged) {
            if (i > 0) pageRuler(c, doc.pageNumber(i), count);
            pageView(app, c, tab, i);
        } else {
            paragraphView(app, c, tab, i);
        }
    }

    // The room below the window.
    if (last < count) {
        _ = c.leaf(.{ .width = .fill, .height = .{ .px = offsetOf(&tab.reader, count, paged) - offsetOf(&tab.reader, last, paged) } }, .none, "reader-after");
    }
    ui.end(c); // the measure column
    ui.end(c); // the centring column
    ui.end(c); // the scroll
}

fn emptyState(c: *ui.Context, doc: *const model.Doc) void {
    const th = c.theme;
    ui.column(c, .{ .width = .fill, .height = .fill, .align_items = .center, .justify = .center, .gap = 8 });
    const what: []const u8 = if (doc.kind == .text and doc.source.path.len > 0)
        "This file is empty — write it in the summary below."
    else if (doc.source.path.len > 0)
        "Nothing to read here."
    else
        "No document open.";
    ui.text(c, what, .{ .size = 14, .color = th.muted });
    if (doc.kind == .pdf) {
        ui.text(c, "This PDF has no text layer: it may be a scan.", .{ .size = 12, .color = th.muted.alpha(0.8) });
    }
    ui.end(c);
}

fn pageRuler(c: *ui.Context, page: u32, count: usize) void {
    const th = c.theme;
    ui.row(c, .{ .width = .fill, .height = .{ .px = ruler_height }, .align_items = .center, .gap = 10 });
    _ = c.leaf(.{ .grow = 1, .height = .{ .px = 1 }, .background = th.border }, .none, null);
    ui.textf(c, .{ .size = 10.5, .color = th.muted, .tabular = true }, "Page {d} / {d}", .{ page, count });
    _ = c.leaf(.{ .grow = 1, .height = .{ .px = 1 }, .background = th.border }, .none, null);
    ui.end(c);
}

fn pageView(app: anytype, c: *ui.Context, tab: anytype, index: usize) void {
    const th = c.theme;
    const doc = tab.doc;
    const blocks = doc.pageBlocks(index);
    ui.keyInt(c, index);
    const page_id = c.peekId(null);
    ui.column(c, .{
        .width = .fill,
        .padding = .{ .left = 26, .right = 26, .top = 22, .bottom = 26 },
        .gap = 10,
        .background = th.surface,
        .border = th.border,
    });
    ui.key(c, "page-label");
    ui.row(c, .{ .width = .fill, .height = .{ .px = 16 }, .align_items = .center });
    ui.textf(c, .{ .size = 10, .color = th.muted.alpha(0.7), .tracking = 0.5 }, "PAGE {d}", .{doc.pageNumber(index)});
    ui.spacer(c);
    ui.textf(c, .{ .size = 10, .color = th.muted.alpha(0.7) }, "{d} blocks", .{blocks.len});
    ui.end(c);
    for (blocks) |block| blockView(app, c, tab, block);
    ui.end(c);
    measureItem(&tab.reader, c, page_id, index);
}

fn blockView(app: anytype, c: *ui.Context, tab: anytype, block: model.Block) void {
    const th = c.theme;
    const zoom = app.zoom_value;
    const highlighted = if (tab.highlights) |hl| hl.get(block.id) else null;
    var style: ui.Style = .{
        .direction = .column,
        .width = .fill,
        .padding = .xy(4, 3),
        .gap = 0,
    };
    if (highlighted != null) style.background = theme.highlightColor(th.dark).alpha(0.16);
    const it = ui.pressable(c, style, th.surface_hover);
    if (highlighted != null) {
        _ = c.leaf(.{
            .absolute = true,
            .width = .{ .px = 2 },
            .height = .fill,
            .background = theme.highlightColor(th.dark),
            .offset = .{ .x = -4, .y = 0 },
        }, .none, null);
    }
    ui.text(c, block.text, .{
        .size = 13.5 * zoom,
        .color = th.text,
        .wrap = true,
        .leading = 1.5,
    });
    ui.end(c);
    if (it.clicked) {
        tab.reader.selectBlock(app.gpa, block.id, block.text);
        tab.reader.sel_rect = it.rect;
        app.selection_changed = true;
    }
}

fn paragraphView(app: anytype, c: *ui.Context, tab: anytype, index: usize) void {
    const th = c.theme;
    const doc = tab.doc;
    if (index >= doc.paragraphs.len) return;
    const para = doc.paragraphs[index];
    const zoom = app.zoom_value;
    const highlighted = if (tab.highlights) |hl| hl.get(para.id) else null;
    const level = para.headingLevel();
    const style: ui.Style = .{
        .direction = .column,
        .width = .fill,
        .padding = .xy(4, 3),
        .background = if (highlighted != null) theme.highlightColor(th.dark).alpha(0.16) else null,
    };
    ui.keyInt(c, index);
    const id = c.peekId(null);
    const it = ui.pressable(c, style, th.surface_hover);
    if (para.text.len == 0) {
        // An empty paragraph still takes a line, so spacing survives.
        ui.text(c, " ", .{ .size = 7 * zoom });
    } else if (para.isBullet()) {
        ui.row(c, .{ .width = .fill, .gap = 8, .align_items = .start });
        ui.text(c, "•", .{ .size = 13.5 * zoom, .color = th.muted });
        ui.text(c, para.text, .{ .size = 14 * zoom, .wrap = true, .leading = 1.55, .color = th.text });
        ui.end(c);
    } else if (level > 0) {
        ui.text(c, para.text, .{
            .size = switch (level) {
                1 => 22 * zoom,
                2 => 18 * zoom,
                else => 15.5 * zoom,
            },
            .weight = if (level == 1) .bold else .semibold,
            .wrap = true,
            .leading = 1.3,
            .color = th.text,
        });
    } else {
        ui.text(c, para.text, .{ .size = 14 * zoom, .wrap = true, .leading = 1.55, .color = th.text });
    }
    ui.end(c);
    measureItem(&tab.reader, c, id, index);
    if (it.clicked) {
        tab.reader.selectBlock(app.gpa, para.id, para.text);
        tab.reader.sel_rect = it.rect;
        app.selection_changed = true;
    }
}

/// Records the height the layout gave an item last frame.
pub fn measureItem(st: *State, c: *ui.Context, id: u64, index: usize) void {
    if (index >= st.heights.items.len) return;
    if (c.rects.get(id)) |r| {
        if (r.h > 0) st.heights.items[index] = r.h;
    }
}

// --- tests -----------------------------------------------------------------

fn testState() State {
    return .{};
}

test "offsets add up measured heights" {
    var st = testState();
    defer st.deinit(std.testing.allocator);
    try st.heights.append(std.testing.allocator, 100);
    try st.heights.append(std.testing.allocator, 200);
    try st.heights.append(std.testing.allocator, 0);
    try std.testing.expectEqual(@as(f32, 0), offsetOf(&st, 0, false));
    try std.testing.expectEqual(@as(f32, 100), offsetOf(&st, 1, false));
    try std.testing.expectEqual(@as(f32, 300), offsetOf(&st, 2, false));
    // An unmeasured item takes the estimate.
    try std.testing.expectEqual(@as(f32, 300 + para_estimate), offsetOf(&st, 3, false));
}

test "the item at an offset" {
    var st = testState();
    defer st.deinit(std.testing.allocator);
    try st.heights.append(std.testing.allocator, 100);
    try st.heights.append(std.testing.allocator, 100);
    try st.heights.append(std.testing.allocator, 100);
    try std.testing.expectEqual(@as(usize, 0), itemAt(&st, 0, 3, false));
    try std.testing.expectEqual(@as(usize, 0), itemAt(&st, 99, 3, false));
    try std.testing.expectEqual(@as(usize, 1), itemAt(&st, 100, 3, false));
    try std.testing.expectEqual(@as(usize, 2), itemAt(&st, 250, 3, false));
    try std.testing.expectEqual(@as(usize, 2), itemAt(&st, 9000, 3, false));
    try std.testing.expectEqual(@as(usize, 0), itemAt(&st, 0, 0, false));
}

test "paged offsets carry the ruler" {
    var st = testState();
    defer st.deinit(std.testing.allocator);
    try st.heights.append(std.testing.allocator, 100);
    try st.heights.append(std.testing.allocator, 100);
    try std.testing.expectEqual(@as(f32, 100 + page_gap + ruler_height), offsetOf(&st, 1, true));
}

test "selection bookkeeping" {
    const a = std.testing.allocator;
    var st = testState();
    defer st.deinit(a);
    st.selectBlock(a, "p1b2", "some text");
    try std.testing.expectEqualStrings("p1b2", st.sel_block.?);
    try std.testing.expectEqualStrings("some text", st.sel_text.?);
    st.selectBlock(a, "p1b3", "other");
    try std.testing.expectEqualStrings("p1b3", st.sel_block.?);
    st.clearSelection(a);
    try std.testing.expectEqual(@as(?[]u8, null), st.sel_block);
}
