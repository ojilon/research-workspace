const std = @import("std");
const nanoui = @import("nanoui");
const ui = nanoui.ui;
const theme = @import("theme.zig");
const sidebar = @import("sidebar.zig");
const tabs = @import("tabs.zig");
const reader_pane = @import("reader_pane.zig");
const editor_pane = @import("editor_pane.zig");
const statusbar = @import("statusbar.zig");

// Dummy documents, one per tab. Phase 2 replaces these with PDF/DOCX text
// extracted to JSON, written back to source files after a safety check.
const Page = reader_pane.Page;

const docs = [_]Page{
    .{
        .paras = &[_][]const u8{
            "Welcome to revise — exam revision notes. Everything below is hardcoded dummy data (step 3): no PDF, DOCX, Python or sqlite yet.",
            "Review each card at the edge of forgetting. Spaced repetition beats cramming: revisit material at gradually longer intervals and it sticks.",
            "Active recall beats re-reading: close the notes and write down what you remember before checking it.",
        },
    },
    .{
        .paras = &[_][]const u8{
            "Page 2 continues the sample. Paragraphs are separated by normal spacing, and a thin ruler marks each page turn.",
            "The highlighted sentence below marks what to memorise first before anything else on this page.",
        },
    },
    .{
        .paras = &[_][]const u8{
            "Settings tab placeholder. Phase 2 wires up PDF/DOCX import, the linked-file index and search here.",
        },
    },
};

var folder_data = [_]sidebar.Folder{
    .{ .name = "Exams", .open = true, .files = &[_][]const u8{ "Biology.md", "Chemistry.md", "Math.md" } },
    .{ .name = "Review", .open = false, .files = &[_][]const u8{"Mock 1.md"} },
};

pub const App = struct {
    tabs: tabs.Tabs = .{
        .labels = &[_][]const u8{ "Notes", "Reader", "Settings" },
        .unsaved = .{ false, true, false },
        .active = 0,
    },
    sidebar: sidebar.Sidebar = .{
        .selected = null,
        .folders = &folder_data,
    },
    reader: reader_pane.Reader = .{},
    editor: editor_pane.Editor = .{},
    status: statusbar.StatusBar = .{},
    split: f32 = 0.55,
    dragging: bool = false,
    last_mouse: ?ui.Point = null,

    fn view(s: *App, c: *ui.Context) void {
        const th = c.theme;
        ui.column(c, .{ .width = .fill, .height = .fill });
        ui.row(c, .{ .width = .fill, .height = .fill });
        s.sidebar.view(c);
        ui.column(c, .{ .grow = 1, .width = .fill, .gap = 0 });
        s.tabs.view(c);

        // split container; its rect sizes divider drags.
        ui.key(c, "main-split");
        const split_id = c.peekId(null);
        const main_rect = c.rects.get(split_id);
        ui.column(c, .{ .grow = 1, .width = .fill, .gap = 0 });
        // top pane: read-only reader
        _ = c.open(.{ .direction = .column, .width = .fill, .grow = s.split }, null);
        //reader_pane.view(&s.reader, c);
        c.end();
        // divider: draggable, clamps to [0.25, 0.75] of the split area.
        const it = ui.pressable(c, .{
            .direction = .row,
            .width = .fill,
            .height = .{ .px = 6 },
        }, th.accent_hover);
        ui.end(c);
        if (it.pressed and c.input.down) {
            if (!s.dragging) {
                s.dragging = true;
                s.last_mouse = c.input.mouse;
            }
            if (s.last_mouse) |lm| {
                if (main_rect) |r| {
                    var ns = s.split + (c.input.mouse.y - lm.y) / @max(1, r.h);
                    ns = std.math.clamp(ns, 0.25, 0.75);
                    if (ns != s.split) {
                        s.split = ns;
                        c.changed = true;
                        c.animationFrame();
                    }
                    s.last_mouse = c.input.mouse;
                }
            }
        } else if (s.dragging) {
            s.dragging = false;
            s.last_mouse = null;
        }
        // bottom pane: editable editor, with a spacer so it looks filled.
        _ = c.open(.{ .direction = .column, .width = .fill, .grow = 1 - s.split }, null);
        s.editor.view(c);
        ui.spacer(c);
        c.end();
        ui.end(c); // split column
        ui.end(c); // main column
        ui.end(c); // row
        // status bar (full width)
        var words: usize = 0;
        var tok = std.mem.tokenizeAny(u8, s.editor.buffer.text(), " \t\r\n");
        while (tok.next()) |_| words += 1;

        s.status = .{
            .path = "notes/chapter1.md",
            .page = 1,
            .total_pages = docs.len,
            .words = words,
        };
        s.status.view(c);
        ui.end(c); // outer column

        //after the panes are drawn, show dot in unsaved edits
        s.tabs.unsaved[s.tabs.active] = s.editor.dirty;
    }
};

pub fn main(init: std.process.Init) !void {
    const app = try nanoui.App.create(init, .{ .name = "revise" });
    defer app.destroy();
    var buf: ui.TextBuffer = .{};
    buf.set("Revise anything.\n\nNotes go here. Bold, Italic and Save are dummy toolbar buttons for now.");
    var state: App = .{};
    state.editor = editor_pane.Editor{ .buffer = buf };

    state.reader.pages = &docs;
    state.reader.highlight = docs[1].paras[1];

    _ = try app.newWindow(.{
        .title = "revise",
        .width = 1000,
        .height = 700,
        .min_width = 700,
        .min_height = 500,
        .theme = theme.theme,
        .content = .{ .view = .init(&state, App.view) },
    });
    try app.run();
}
