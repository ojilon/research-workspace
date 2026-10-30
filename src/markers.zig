//! The editor's light markup, the way revise edits it: wrapping a selection
//! in `**` or `*`, the prefix of a heading, and the byte offsets search
//! snippets need. Pure functions, all tested.
const std = @import("std");

pub const bullet = "- ";
pub const bold = "**";
pub const italic = "*";

pub const Edit = struct {
    /// The whole new text (caller owns it).
    text: []u8,
    /// The selection to apply afterwards, as [anchor, caret] byte offsets.
    sel: [2]usize,

    pub fn deinit(self: Edit, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
    }
};

/// Wraps bytes [lo, hi) of `text` in `marker`, or takes the marker off when
/// the selection already has it. With an empty selection the markers are
/// inserted and the caret put between them.
pub fn toggleWrap(
    allocator: std.mem.Allocator,
    text: []const u8,
    lo_in: usize,
    hi_in: usize,
    marker: []const u8,
) !Edit {
    const lo = @min(lo_in, text.len);
    const hi = @min(@max(hi_in, lo), text.len);
    const has_outside = lo >= marker.len and
        hi + marker.len <= text.len and
        std.mem.eql(u8, text[lo - marker.len .. lo], marker) and
        std.mem.eql(u8, text[hi .. hi + marker.len], marker);
    if (has_outside) {
        // Take the markers off: "**bold**" -> "bold".
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        try out.appendSlice(allocator, text[0 .. lo - marker.len]);
        try out.appendSlice(allocator, text[lo..hi]);
        try out.appendSlice(allocator, text[hi + marker.len ..]);
        const new_lo = lo - marker.len;
        return .{
            .text = try out.toOwnedSlice(allocator),
            .sel = .{ new_lo, new_lo + (hi - lo) },
        };
    }
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, text[0..lo]);
    try out.appendSlice(allocator, marker);
    try out.appendSlice(allocator, text[lo..hi]);
    try out.appendSlice(allocator, marker);
    try out.appendSlice(allocator, text[hi..]);
    const inner_lo = lo + marker.len;
    return .{
        .text = try out.toOwnedSlice(allocator),
        .sel = .{ inner_lo, inner_lo + (hi - lo) },
    };
}

/// The prefix that makes a line a heading of this level ("" for body text).
pub fn headingPrefix(level: u8) []const u8 {
    return switch (level) {
        1 => "# ",
        2 => "## ",
        3 => "### ",
        else => "",
    };
}

/// Appends `"- " + text` to `existing` on a line of its own.
pub fn appendBullet(allocator: std.mem.Allocator, existing: []const u8, text: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, existing);
    if (existing.len > 0 and existing[existing.len - 1] != '\n') try out.append(allocator, '\n');
    if (existing.len > 0) try out.append(allocator, '\n');
    try out.appendSlice(allocator, bullet);
    try out.appendSlice(allocator, std.mem.trim(u8, text, " \t\r\n"));
    return out.toOwnedSlice(allocator);
}

/// Puts `prefix` at the start of the line the caret is on, or takes it off
/// when the line already begins with it: Heading, Bullet in the toolbar.
pub fn toggleLinePrefix(allocator: std.mem.Allocator, text: []const u8, caret_in: usize, prefix: []const u8) !Edit {
    const caret = @min(caret_in, text.len);
    const line_start = if (std.mem.lastIndexOfScalar(u8, text[0..caret], '\n')) |i| i + 1 else 0;
    const line_end = std.mem.indexOfScalarPos(u8, text, line_start, '\n') orelse text.len;
    const line = text[line_start..line_end];

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    if (std.mem.startsWith(u8, line, prefix) and line.len > prefix.len) {
        try out.appendSlice(allocator, text[0..line_start]);
        try out.appendSlice(allocator, line[prefix.len..]);
        try out.appendSlice(allocator, text[line_end..]);
        const removed = @min(prefix.len, caret - line_start);
        return .{ .text = try out.toOwnedSlice(allocator), .sel = .{ caret - removed, caret - removed } };
    }
    try out.appendSlice(allocator, text[0..line_start]);
    try out.appendSlice(allocator, prefix);
    try out.appendSlice(allocator, text[line_start..]);
    return .{ .text = try out.toOwnedSlice(allocator), .sel = .{ caret + prefix.len, caret + prefix.len } };
}

/// The byte offset of code point `cp` in `text` (clamped to its length).
/// Python counts a snippet's offsets in characters; drawing them needs bytes.
pub fn cpToByte(text: []const u8, cp: usize) usize {
    var byte: usize = 0;
    var n: usize = 0;
    while (byte < text.len and n < cp) : (n += 1) {
        byte += std.unicode.utf8ByteSequenceLength(text[byte]) catch 1;
    }
    return @min(byte, text.len);
}

/// What the status bar says about a line: the marker form's kind.
pub fn lineKind(line: []const u8) enum { heading, bullet, body } {
    if (std.mem.startsWith(u8, line, "# ") or std.mem.startsWith(u8, line, "## ") or std.mem.startsWith(u8, line, "### ")) return .heading;
    if (std.mem.startsWith(u8, line, "- ")) return .bullet;
    return .body;
}

test "wrap a selection in bold" {
    const a = std.testing.allocator;
    const e = try toggleWrap(a, "make ATP now", 5, 8, bold);
    defer e.deinit(a);
    try std.testing.expectEqualStrings("make **ATP** now", e.text);
    try std.testing.expectEqual([2]usize{ 7, 10 }, e.sel);
}

test "wrapping twice takes the markers off" {
    const a = std.testing.allocator;
    const once = try toggleWrap(a, "make ATP now", 5, 8, bold);
    defer once.deinit(a);
    const twice = try toggleWrap(a, once.text, once.sel[0], once.sel[1], bold);
    defer twice.deinit(a);
    try std.testing.expectEqualStrings("make ATP now", twice.text);
    try std.testing.expectEqual([2]usize{ 5, 8 }, twice.sel);
}

test "no selection inserts the markers and puts the caret inside" {
    const a = std.testing.allocator;
    const e = try toggleWrap(a, "abc", 3, 3, italic);
    defer e.deinit(a);
    try std.testing.expectEqualStrings("abc**", e.text); // marker is '*'
}

test "an empty selection inside text" {
    const a = std.testing.allocator;
    const e = try toggleWrap(a, "abcdef", 2, 2, italic);
    defer e.deinit(a);
    try std.testing.expectEqualStrings("ab**cdef", e.text);
    try std.testing.expectEqual([2]usize{ 3, 3 }, e.sel);
}

test "clamps out-of-range selections" {
    const a = std.testing.allocator;
    const e = try toggleWrap(a, "abc", 9, 99, bold);
    defer e.deinit(a);
    try std.testing.expectEqualStrings("abc****", e.text);
}

test "bullets are appended on their own line" {
    const a = std.testing.allocator;
    const one = try appendBullet(a, "", "First idea");
    defer a.free(one);
    try std.testing.expectEqualStrings("- First idea", one);

    const two = try appendBullet(a, "Intro", "  Second idea  ");
    defer a.free(two);
    try std.testing.expectEqualStrings("Intro\n\n- Second idea", two);

    const three = try appendBullet(a, "Intro\n", "Third");
    defer a.free(three);
    try std.testing.expectEqualStrings("Intro\n\n- Third", three);
}

test "headings" {
    try std.testing.expectEqualStrings("# ", headingPrefix(1));
    try std.testing.expectEqualStrings("## ", headingPrefix(2));
    try std.testing.expectEqualStrings("", headingPrefix(0));
}

test "code points to bytes" {
    try std.testing.expectEqual(@as(usize, 0), cpToByte("abc", 0));
    try std.testing.expectEqual(@as(usize, 2), cpToByte("abc", 2));
    try std.testing.expectEqual(@as(usize, 3), cpToByte("abc", 9));
    // "é" is two bytes.
    try std.testing.expectEqual(@as(usize, 3), cpToByte("aéb", 2));
    try std.testing.expectEqual(@as(usize, 6), cpToByte("日本", 2));
    // A truncated sequence does not loop for ever.
    try std.testing.expectEqual(@as(usize, 1), cpToByte("\xffa", 1));
}

test "line kinds" {
    try std.testing.expectEqual(.heading, lineKind("# Title"));
    try std.testing.expectEqual(.heading, lineKind("### Deep"));
    try std.testing.expectEqual(.bullet, lineKind("- item"));
    try std.testing.expectEqual(.body, lineKind("plain"));
}

test "a heading prefix goes on and comes off" {
    const a = std.testing.allocator;
    const on = try toggleLinePrefix(a, "one\ntwo\nthree", 6, "## ");
    defer on.deinit(a);
    try std.testing.expectEqualStrings("one\n## two\nthree", on.text);
    try std.testing.expectEqual([2]usize{ 9, 9 }, on.sel);

    const off = try toggleLinePrefix(a, on.text, 9, "## ");
    defer off.deinit(a);
    try std.testing.expectEqualStrings("one\ntwo\nthree", off.text);
    try std.testing.expectEqual([2]usize{ 6, 6 }, off.sel);

    // A bullet on an empty line keeps the marker, so typing continues it.
    const empty = try toggleLinePrefix(a, "", 0, "- ");
    defer empty.deinit(a);
    try std.testing.expectEqualStrings("- ", empty.text);
}
