//! Where things live: the cache, summaries, backups, and the kinds of files
//! revise understands. Pure string work, so it is tested without a window.
const std = @import("std");
const builtin = @import("builtin");

pub const Kind = enum {
    pdf,
    docx,
    /// Markdown or plain text: editable in place.
    text,

    pub fn fromExtension(ext: []const u8) ?Kind {
        if (std.ascii.eqlIgnoreCase(ext, ".pdf")) return .pdf;
        if (std.ascii.eqlIgnoreCase(ext, ".docx")) return .docx;
        if (std.ascii.eqlIgnoreCase(ext, ".md")) return .text;
        if (std.ascii.eqlIgnoreCase(ext, ".markdown")) return .text;
        if (std.ascii.eqlIgnoreCase(ext, ".txt")) return .text;
        return null;
    }

    /// The `kind` a document's JSON carries.
    pub fn wireName(k: Kind) []const u8 {
        return switch (k) {
            .pdf => "pdf",
            .docx => "docx",
            .text => "text",
        };
    }
};

pub fn kindOf(path: []const u8) ?Kind {
    return Kind.fromExtension(std.fs.path.extension(path));
}

pub fn isSupported(path: []const u8) bool {
    return kindOf(path) != null;
}

/// Lowercase extension with its dot ("" when there is none).
pub fn lowerExtension(path: []const u8) []const u8 {
    return std.fs.path.extension(path);
}

pub fn basename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

pub fn dirname(path: []const u8) []const u8 {
    return std.fs.path.dirname(path) orelse "";
}

/// The file's name without its extension: the name of its summary.
pub fn stem(path: []const u8) []const u8 {
    const base = basename(path);
    const ext = std.fs.path.extension(base);
    return base[0 .. base.len - ext.len];
}

pub fn join(allocator: std.mem.Allocator, parts: []const []const u8) ![]u8 {
    return std.fs.path.join(allocator, parts);
}

/// `path` made absolute against `cwd`, with the case folded on Windows (as
/// Python's `os.path.normcase` does).
pub fn absoluteNorm(allocator: std.mem.Allocator, path: []const u8, cwd: []const u8) ![]u8 {
    const joined = if (std.fs.path.isAbsolute(path))
        try allocator.dupe(u8, path)
    else
        try join(allocator, &.{ cwd, path });
    errdefer allocator.free(joined);
    if (builtin.os.tag == .windows) {
        for (joined) |*ch| ch.* = std.ascii.toLower(ch.*);
    }
    return joined;
}

/// The key Python uses for the cache file: sha1 of the absolute path, hex.
pub fn cacheKey(allocator: std.mem.Allocator, path: []const u8, cwd: []const u8) ![]u8 {
    const norm = try absoluteNorm(allocator, path, cwd);
    defer allocator.free(norm);
    var digest: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(norm, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return allocator.dupe(u8, &hex);
}

pub fn cacheDir(allocator: std.mem.Allocator, root: []const u8) ![]u8 {
    return join(allocator, &.{ root, ".revise", "cache" });
}

pub fn reviseDir(allocator: std.mem.Allocator, root: []const u8) ![]u8 {
    return join(allocator, &.{ root, ".revise" });
}

pub fn summariesDir(allocator: std.mem.Allocator, root: []const u8) ![]u8 {
    return join(allocator, &.{ root, ".revise", "summaries" });
}

pub fn tmpDir(allocator: std.mem.Allocator, root: []const u8) ![]u8 {
    return join(allocator, &.{ root, ".revise", "tmp" });
}

pub fn dbFile(allocator: std.mem.Allocator, root: []const u8) ![]u8 {
    return join(allocator, &.{ root, ".revise", "revise.db" });
}

/// `<root>/.revise/cache/<sha1>.json`
pub fn cacheFile(
    allocator: std.mem.Allocator,
    root: []const u8,
    path: []const u8,
    cwd: []const u8,
) ![]u8 {
    const key = try cacheKey(allocator, path, cwd);
    defer allocator.free(key);
    const name = try std.fmt.allocPrint(allocator, "{s}.json", .{key});
    defer allocator.free(name);
    return join(allocator, &.{ root, ".revise", "cache", name });
}

/// Where the summary of `path` is saved: `<root>/.revise/summaries/<stem>-summary.docx`
pub fn summaryFile(allocator: std.mem.Allocator, root: []const u8, path: []const u8) ![]u8 {
    const name = try std.fmt.allocPrint(allocator, "{s}-summary.docx", .{stem(path)});
    defer allocator.free(name);
    return join(allocator, &.{ root, ".revise", "summaries", name });
}

/// A place to write the editor's text for a tool to read.
pub fn markersFile(allocator: std.mem.Allocator, root: []const u8, stamp: u64) ![]u8 {
    const name = try std.fmt.allocPrint(allocator, "markers-{d}.txt", .{stamp});
    defer allocator.free(name);
    return join(allocator, &.{ root, ".revise", "tmp", name });
}

/// Whether `path` is inside `root` (both absolute, no symlinks resolved).
pub fn isInside(root: []const u8, path: []const u8) bool {
    if (!std.mem.startsWith(u8, path, root)) return false;
    if (path.len == root.len) return true;
    return path[root.len] == std.fs.path.sep or path[root.len] == '/';
}

/// `a/b/c.txt` → the name shown in the tree and the tab strip.
pub fn displayName(path: []const u8) []const u8 {
    return basename(path);
}

test "kinds by extension" {
    try std.testing.expectEqual(Kind.pdf, kindOf("x/y/Paper.PDF").?);
    try std.testing.expectEqual(Kind.docx, kindOf("notes.docx").?);
    try std.testing.expectEqual(Kind.text, kindOf("plan.md").?);
    try std.testing.expectEqual(Kind.text, kindOf("plan.markdown").?);
    try std.testing.expectEqual(Kind.text, kindOf("plan.txt").?);
    try std.testing.expect(kindOf("plan.odt") == null);
    try std.testing.expect(!isSupported("image.png"));
}

test "stems and names" {
    try std.testing.expectEqualStrings("biology", stem("/a/b/biology.docx"));
    try std.testing.expectEqualStrings("biology", stem("biology.docx"));
    try std.testing.expectEqualStrings("no-ext", stem("no-ext"));
    try std.testing.expectEqualStrings("biology.docx", basename("/x/y/biology.docx"));
    try std.testing.expectEqualStrings("/x/y", dirname("/x/y/biology.docx"));
}

test "cache key is sha1 of the absolute path" {
    const a = std.testing.allocator;
    const key = try cacheKey(a, "/work/notes.md", "/work");
    defer a.free(key);
    var digest: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash("/work/notes.md", &digest, .{});
    try std.testing.expectEqualStrings(&std.fmt.bytesToHex(digest, .lower), key);
    // A relative path resolves against the working directory.
    const rel = try cacheKey(a, "notes.md", "/work");
    defer a.free(rel);
    try std.testing.expectEqualStrings(key, rel);
}

test "cache and summary paths" {
    const a = std.testing.allocator;
    const cache = try cacheFile(a, "/root", "/root/x/paper.pdf", "/root");
    defer a.free(cache);
    try std.testing.expect(std.mem.startsWith(u8, cache, "/root/.revise/cache/"));
    try std.testing.expect(std.mem.endsWith(u8, cache, ".json"));

    const summary = try summaryFile(a, "/root", "/root/exams/biology.docx");
    defer a.free(summary);
    try std.testing.expectEqualStrings("/root/.revise/summaries/biology-summary.docx", summary);

    const markers = try markersFile(a, "/root", 42);
    defer a.free(markers);
    try std.testing.expectEqualStrings("/root/.revise/tmp/markers-42.txt", markers);
}

