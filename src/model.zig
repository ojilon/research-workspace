//! The documents revise reads: the JSON that tools/extract.py prints, parsed
//! with std.json into pages of blocks (PDF) or paragraphs (DOCX, Markdown,
//! text), plus the database rows the app draws over them.
//!
//! Nothing here touches the screen, so all of it is tested by `zig test`.
const std = @import("std");
const paths = @import("paths.zig");

pub const Source = struct {
    path: []const u8 = "",
    kind: []const u8 = "",
    size: u64 = 0,
    /// Nanoseconds since the epoch, as Python's `st_mtime_ns`.
    mtime: i64 = 0,
    sha256: []const u8 = "",
};

pub const Block = struct {
    id: []const u8 = "",
    text: []const u8 = "",
    bbox: [4]f32 = .{ 0, 0, 0, 0 },
};

pub const Page = struct {
    n: u32 = 0,
    blocks: []const Block = &.{},
};

pub const Para = struct {
    id: []const u8 = "",
    style: []const u8 = "Normal",
    text: []const u8 = "",
    /// The same paragraph in the editor's marker form.
    markers: []const u8 = "",

    pub fn headingLevel(p: Para) u8 {
        const s = p.style;
        if (std.mem.eql(u8, s, "Heading 1")) return 1;
        if (std.mem.eql(u8, s, "Heading 2")) return 2;
        if (std.mem.eql(u8, s, "Heading 3")) return 3;
        return 0;
    }

    pub fn isBullet(p: Para) bool {
        return std.mem.eql(u8, p.style, "List Bullet");
    }
};

const Wire = struct {
    schema_version: u32 = 1,
    source: Source = .{},
    pages: []const Page = &.{},
    paragraphs: []const Para = &.{},
};

pub const Doc = struct {
    arena: std.heap.ArenaAllocator,
    source: Source = .{},
    kind: paths.Kind = .text,
    pages: []const Page = &.{},
    paragraphs: []const Para = &.{},
    /// Marker text of the whole document (for a text file: its own text).
    markers: []const u8 = "",

    pub fn deinit(self: *Doc, gpa: std.mem.Allocator) void {
        self.arena.deinit();
        gpa.destroy(self);
    }

    /// How many things the reader scrolls through: pages, or paragraphs.
    pub fn itemCount(self: *const Doc) usize {
        return if (self.kind == .pdf) self.pages.len else self.paragraphs.len;
    }

    pub fn isPaged(self: *const Doc) bool {
        return self.kind == .pdf;
    }

    pub fn empty(self: *const Doc) bool {
        return self.itemCount() == 0;
    }

    /// The blocks of a page (empty for a paragraph document).
    pub fn pageBlocks(self: *const Doc, index: usize) []const Block {
        if (self.kind != .pdf or index >= self.pages.len) return &.{};
        return self.pages[index].blocks;
    }

    pub fn pageNumber(self: *const Doc, index: usize) u32 {
        if (self.kind != .pdf or index >= self.pages.len) return @intCast(index + 1);
        return self.pages[index].n;
    }

    pub fn wordCount(self: *const Doc) usize {
        var n: usize = 0;
        if (self.kind == .pdf) {
            for (self.pages) |p| {
                for (p.blocks) |b| n += countWords(b.text);
            }
        } else {
            for (self.paragraphs) |p| n += countWords(p.text);
        }
        return n;
    }

    /// The paragraph with this id, if the document has one.
    pub fn paraById(self: *const Doc, id: []const u8) ?*const Para {
        for (self.paragraphs) |*p| {
            if (std.mem.eql(u8, p.id, id)) return p;
        }
        return null;
    }

    /// The text to show in the editor the first time a text file is opened:
    /// its own marker text.
    pub fn markerText(self: *const Doc, allocator: std.mem.Allocator) ![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        if (self.kind == .pdf) return out.toOwnedSlice(allocator);
        for (self.paragraphs, 0..) |p, i| {
            if (i > 0) try out.append(allocator, '\n');
            try out.appendSlice(allocator, if (p.markers.len > 0) p.markers else p.text);
        }
        return out.toOwnedSlice(allocator);
    }
};

pub fn countWords(text: []const u8) usize {
    var n: usize = 0;
    var it = std.mem.tokenizeAny(u8, text, " \t\r\n");
    while (it.next()) |_| n += 1;
    return n;
}

/// Parses one extraction. `fallback_kind` is used when the JSON's `kind` is
/// missing or unknown, so a malformed field never costs the document.
pub fn parse(gpa: std.mem.Allocator, bytes: []const u8, fallback_kind: paths.Kind) !*Doc {
    const self = try gpa.create(Doc);
    self.* = .{ .arena = std.heap.ArenaAllocator.init(gpa), .kind = fallback_kind };
    errdefer {
        self.arena.deinit();
        gpa.destroy(self);
    }
    const allocator = self.arena.allocator();
    const wire = try std.json.parseFromSliceLeaky(Wire, allocator, bytes, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    self.source = wire.source;
    self.pages = wire.pages;
    self.paragraphs = wire.paragraphs;
    self.kind = if (std.mem.eql(u8, wire.source.kind, "pdf"))
        .pdf
    else if (std.mem.eql(u8, wire.source.kind, "docx"))
        .docx
    else if (std.mem.eql(u8, wire.source.kind, "text"))
        .text
    else
        fallback_kind;
    self.markers = try self.markerText(allocator);
    return self;
}

/// A row of `highlights`.
pub const Highlight = struct {
    id: i64 = 0,
    path: []const u8 = "",
    block_id: []const u8 = "",
    text: []const u8 = "",
    color: []const u8 = "yellow",
    created: i64 = 0,
};

pub const HighlightList = struct {
    arena: std.heap.ArenaAllocator,
    items: []const Highlight = &.{},

    pub fn deinit(self: *HighlightList, gpa: std.mem.Allocator) void {
        self.arena.deinit();
        gpa.destroy(self);
    }

    pub fn has(self: *const HighlightList, block_id: []const u8) bool {
        for (self.items) |h| {
            if (std.mem.eql(u8, h.block_id, block_id)) return true;
        }
        return false;
    }

    pub fn get(self: *const HighlightList, block_id: []const u8) ?Highlight {
        for (self.items) |h| {
            if (std.mem.eql(u8, h.block_id, block_id)) return h;
        }
        return null;
    }
};

/// Parses `db.py hl-list`. A document with no highlights, or a failed call,
/// is simply a list with nothing in it.
pub fn parseHighlights(gpa: std.mem.Allocator, bytes: []const u8) !*HighlightList {
    const self = try gpa.create(HighlightList);
    self.* = .{ .arena = std.heap.ArenaAllocator.init(gpa) };
    errdefer {
        self.arena.deinit();
        gpa.destroy(self);
    }
    const WireList = struct {
        highlights: []const Highlight = &.{},
    };
    const wire = try std.json.parseFromSliceLeaky(WireList, self.arena.allocator(), bytes, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    self.items = wire.highlights;
    return self;
}

/// One `db.py search` result.
pub const SearchHit = struct {
    path: []const u8 = "",
    page: u32 = 0,
    kind: []const u8 = "",
    snippet: []const u8 = "",
    hit: [2]usize = .{ 0, 0 },
};

pub const SearchResults = struct {
    arena: std.heap.ArenaAllocator,
    query: []const u8 = "",
    fts5: bool = false,
    items: []const SearchHit = &.{},

    pub fn deinit(self: *SearchResults, gpa: std.mem.Allocator) void {
        self.arena.deinit();
        gpa.destroy(self);
    }
};

pub fn parseSearch(gpa: std.mem.Allocator, bytes: []const u8) !*SearchResults {
    const self = try gpa.create(SearchResults);
    self.* = .{ .arena = std.heap.ArenaAllocator.init(gpa) };
    errdefer {
        self.arena.deinit();
        gpa.destroy(self);
    }
    const WireResults = struct {
        query: []const u8 = "",
        fts5: bool = false,
        results: []const SearchHit = &.{},
        @"error": ?[]const u8 = null,
    };
    const wire = try std.json.parseFromSliceLeaky(WireResults, self.arena.allocator(), bytes, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    if (wire.@"error") |e| {
        _ = e;
        return error.ToolError;
    }
    self.query = wire.query;
    self.fts5 = wire.fts5;
    self.items = wire.results;
    return self;
}

/// One entry of `db.py files`.
pub const FileEntry = struct {
    path: []const u8 = "",
    linked: bool = false,
    alias: []const u8 = "",
};

pub const FileList = struct {
    arena: std.heap.ArenaAllocator,
    items: []const FileEntry = &.{},

    pub fn deinit(self: *FileList, gpa: std.mem.Allocator) void {
        self.arena.deinit();
        gpa.destroy(self);
    }
};

pub fn parseFiles(gpa: std.mem.Allocator, bytes: []const u8) !*FileList {
    const self = try gpa.create(FileList);
    self.* = .{ .arena = std.heap.ArenaAllocator.init(gpa) };
    errdefer {
        self.arena.deinit();
        gpa.destroy(self);
    }
    const WireFiles = struct {
        files: []const FileEntry = &.{},
    };
    const wire = try std.json.parseFromSliceLeaky(WireFiles, self.arena.allocator(), bytes, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    self.items = wire.files;
    return self;
}

/// One entry of `db.py links`.
pub const LinkEntry = struct {
    path: []const u8 = "",
    alias: []const u8 = "",
    exists: bool = true,
};

pub const LinkList = struct {
    arena: std.heap.ArenaAllocator,
    items: []const LinkEntry = &.{},

    pub fn deinit(self: *LinkList, gpa: std.mem.Allocator) void {
        self.arena.deinit();
        gpa.destroy(self);
    }
};

pub fn parseLinks(gpa: std.mem.Allocator, bytes: []const u8) !*LinkList {
    const self = try gpa.create(LinkList);
    self.* = .{ .arena = std.heap.ArenaAllocator.init(gpa) };
    errdefer {
        self.arena.deinit();
        gpa.destroy(self);
    }
    const WireLinks = struct {
        links: []const LinkEntry = &.{},
        @"error": ?[]const u8 = null,
    };
    const wire = try std.json.parseFromSliceLeaky(WireLinks, self.arena.allocator(), bytes, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    if (wire.@"error" != null) return error.ToolError;
    self.items = wire.links;
    return self;
}

/// A tool's answer, as much of it as the app looks at.
pub const Reply = struct {
    arena: std.heap.ArenaAllocator,
    ok: bool = false,
    conflict: bool = false,
    created: bool = false,
    reason: []const u8 = "",
    path: []const u8 = "",
    backup: []const u8 = "",
    error_text: []const u8 = "",
    source: Source = .{},

    pub fn deinit(self: *Reply, gpa: std.mem.Allocator) void {
        self.arena.deinit();
        gpa.destroy(self);
    }
};

pub fn parseReply(gpa: std.mem.Allocator, bytes: []const u8) !*Reply {
    const self = try gpa.create(Reply);
    self.* = .{ .arena = std.heap.ArenaAllocator.init(gpa) };
    errdefer {
        self.arena.deinit();
        gpa.destroy(self);
    }
    // `null` for a field a tool leaves out (`"backup": null` when nothing was
    // backed up): optionals, or the whole answer would fail to parse.
    const WireReply = struct {
        ok: bool = false,
        conflict: bool = false,
        created: bool = false,
        reason: ?[]const u8 = null,
        path: ?[]const u8 = null,
        backup: ?[]const u8 = null,
        @"error": ?[]const u8 = null,
        source: Source = .{},
    };
    const wire = try std.json.parseFromSliceLeaky(WireReply, self.arena.allocator(), bytes, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    self.ok = wire.ok;
    self.conflict = wire.conflict;
    self.created = wire.created;
    self.reason = wire.reason orelse "";
    self.path = wire.path orelse "";
    self.backup = wire.backup orelse "";
    self.error_text = wire.@"error" orelse "";
    self.source = wire.source;
    return self;
}

// --- tests -----------------------------------------------------------------

const sample_pdf =
    \\{"schema_version":1,
    \\ "source":{"path":"/w/past.pdf","kind":"pdf","size":12,"mtime":99,"sha256":"ab"},
    \\ "pages":[{"n":1,"blocks":[
    \\   {"id":"p1b1","text":"First paragraph.","bbox":[72,72,400,90]},
    \\   {"id":"p1b2","text":"Second paragraph.","bbox":[72,100,400,140]}]},
    \\  {"n":2,"blocks":[{"id":"p2b1","text":"Page two text.","bbox":[72,72,400,90]}]}]}
;

const sample_docx =
    \\{"schema_version":1,
    \\ "source":{"path":"/w/bio.docx","kind":"docx","size":3,"mtime":1,"sha256":"cd"},
    \\ "paragraphs":[
    \\   {"id":"d1","style":"Heading 1","text":"Cells","markers":"# Cells"},
    \\   {"id":"d2","style":"Normal","text":"Mitochondria make ATP.","markers":"**Mitochondria** make ATP."},
    \\   {"id":"d3","style":"List Bullet","text":"one","markers":"- one"}]}
;

test "parses a pdf extraction" {
    const a = std.testing.allocator;
    const doc = try parse(a, sample_pdf, .pdf);
    defer doc.deinit(a);
    try std.testing.expectEqual(paths.Kind.pdf, doc.kind);
    try std.testing.expectEqual(@as(usize, 2), doc.itemCount());
    try std.testing.expectEqual(@as(u32, 2), doc.pageNumber(1));
    try std.testing.expectEqual(@as(usize, 2), doc.pageBlocks(0).len);
    try std.testing.expectEqualStrings("Second paragraph.", doc.pageBlocks(0)[1].text);
    try std.testing.expectEqual(@as(f32, 400), doc.pageBlocks(1)[0].bbox[2]);
    try std.testing.expectEqual(@as(usize, 7), doc.wordCount());
    try std.testing.expectEqualStrings("/w/past.pdf", doc.source.path);
    try std.testing.expectEqual(@as(i64, 99), doc.source.mtime);
}

test "parses a docx extraction and its styles" {
    const a = std.testing.allocator;
    const doc = try parse(a, sample_docx, .docx);
    defer doc.deinit(a);
    try std.testing.expectEqual(paths.Kind.docx, doc.kind);
    try std.testing.expectEqual(@as(usize, 3), doc.itemCount());
    try std.testing.expectEqual(@as(u8, 1), doc.paragraphs[0].headingLevel());
    try std.testing.expectEqual(@as(u8, 0), doc.paragraphs[1].headingLevel());
    try std.testing.expect(doc.paragraphs[2].isBullet());
    const markers = try doc.markerText(a);
    defer a.free(markers);
    try std.testing.expectEqualStrings("# Cells\n**Mitochondria** make ATP.\n- one", markers);
}

test "empty and unknown documents" {
    const a = std.testing.allocator;
    const doc = try parse(a, "{\"schema_version\":1,\"source\":{\"kind\":\"weird\"}}", .text);
    defer doc.deinit(a);
    try std.testing.expectEqual(paths.Kind.text, doc.kind);
    try std.testing.expect(doc.empty());
    try std.testing.expectEqual(@as(usize, 0), doc.wordCount());
}

test "malformed json is an error, not a crash" {
    const a = std.testing.allocator;
    try std.testing.expectError(error.SyntaxError, parse(a, "{not json", .text));
}

test "parses highlights and search results" {
    const a = std.testing.allocator;
    const hl = try parseHighlights(a, "{\"ok\":true,\"highlights\":[{\"id\":3,\"path\":\"/w/bio.docx\",\"block_id\":\"d2\",\"text\":\"ATP\",\"color\":\"yellow\",\"created\":7}]}");
    defer hl.deinit(a);
    try std.testing.expect(hl.has("d2"));
    try std.testing.expect(!hl.has("d3"));
    try std.testing.expectEqual(@as(i64, 3), hl.get("d2").?.id);

    const results = try parseSearch(a, "{\"ok\":true,\"query\":\"atp\",\"fts5\":true,\"results\":[{\"path\":\"/w/bio.docx\",\"page\":2,\"kind\":\"docx\",\"snippet\":\"make ATP now\",\"hit\":[5,8]}]}");
    defer results.deinit(a);
    try std.testing.expect(results.fts5);
    try std.testing.expectEqual(@as(usize, 1), results.items.len);
    try std.testing.expectEqualStrings("make ATP now", results.items[0].snippet);
    try std.testing.expectEqual(@as(usize, 5), results.items[0].hit[0]);

    const reply = try parseReply(a, "{\"conflict\":true,\"reason\":\"changed\",\"source\":{\"size\":9}}");
    defer reply.deinit(a);
    try std.testing.expect(reply.conflict);
    try std.testing.expectEqual(@as(u64, 9), reply.source.size);

    const failed = try parseReply(a, "{\"error\":\"verify failed\"}");
    defer failed.deinit(a);
    try std.testing.expectEqualStrings("verify failed", failed.error_text);

    const files = try parseFiles(a, "{\"ok\":true,\"files\":[{\"path\":\"/w/a.md\",\"linked\":true,\"alias\":\"spec\"}]}");
    defer files.deinit(a);
    try std.testing.expect(files.items[0].linked);
    try std.testing.expectEqualStrings("spec", files.items[0].alias);
}

test "a reply with null fields still parses" {
    const a = std.testing.allocator;
    const reply = try parseReply(a, "{\"ok\": true, \"created\": true, \"backup\": null, \"path\": \"/w/s.docx\"}");
    defer reply.deinit(a);
    try std.testing.expect(reply.ok);
    try std.testing.expect(reply.created);
    try std.testing.expectEqualStrings("", reply.backup);
}

test "parses the save tools' full answer" {
    const a = std.testing.allocator;
    const bytes =
        \\{"ok": true, "path": "/tmp/exam/.revise/summaries/respiration-summary.docx", "created": false, "backup": "/tmp/exam/.revise/backups/respiration-summary.20261030-153803.docx", "source": {"path": "/tmp/exam/.revise/summaries/respiration-summary.docx", "kind": "docx", "size": 36610, "mtime": 1793374683793156677, "sha256": "c184"}, "paragraphs": 1}
    ;
    const reply = try parseReply(a, bytes);
    defer reply.deinit(a);
    try std.testing.expect(reply.ok);
    try std.testing.expect(!reply.conflict);
    try std.testing.expectEqual(@as(u64, 36610), reply.source.size);
    try std.testing.expectEqualStrings("/tmp/exam/.revise/summaries/respiration-summary.docx", reply.path);
}
