//! Tab strip: hardcoded tabs. The active tab has an accent underline;
//! unsaved tabs show a dot. Clicking a tab switches it.
const ui = @import("nanoui").ui;
const theme = @import("theme.zig");

pub const Tabs = struct {
    labels: []const []const u8 = &.{},
    unsaved: [3]bool = .{false, false, false},
    active: usize = 0,

    pub fn view(s: *Tabs, c: *ui.Context) void {
        const th = c.theme;
        ui.key(c, "tab-strip");
        const strip_id = c.peekId(null);
        ui.row(c, .{ .width = .fill, .height = .{ .px = 34 }, .align_items = .center, .gap = 0 });
        defer ui.end(c);
        // 1px rule under the whole strip, painted underneath the tabs.
        _ = c.leaf(.{ .absolute = true, .offset = .{ .y = 33 }, .width = .fill, .height = .{ .px = 1 }, .background = th.border }, .none, null);
        for (s.labels, 0..) |label, i| {
            ui.key(c, c.print("tab-{d}", .{i}));
            const tab_id = c.peekId(null);

            _= tab_id;
            
            const on = s.active == i;
            const tab = ui.div(c).row().wFull().h(34).gap(10).px(14).itemsCenter().control();
            const it = tab.interaction();
            defer tab.end();
            if (it.clicked and !on) { s.active = i; c.changed = true; c.animationFrame(); }
            const fg = if (on) th.accent else if (it.hovered) th.text else th.muted;
            ui.text(c, label, .{ .size = 13, .weight = if (on) .semibold else .regular, .color = fg });
            if (s.unsaved[i]) {
                _ = c.leaf(.{ .width = .{ .px = 7 }, .height = .{ .px = 7 }, .radius = 3, .background = th.accent }, .none, null);
            }
        }
        // Accent underline of the active tab (from last frame's rect).
        if (s.active < s.labels.len) {
            const tab_id = c.peekId(c.print("tab-{d}", .{s.active}));
            if (c.rects.get(tab_id)) |r| if (c.rects.get(strip_id)) |strip| {
                _ = c.leaf(.{
                    .absolute = true,
                    .offset = .{ .x = r.x - strip.x, .y = strip.h - 2 },
                    .width = .{ .px = r.w },
                    .height = .{ .px = 2 },
                    .background = th.accent,
                }, .none, null);
            };
        }
    }
};
