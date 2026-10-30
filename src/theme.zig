//! Flat, quiet themes: 1 px lines, rectangular corners, one accent colour,
//! no shadows. `dark` is the default (design 01); `light` is design 05.
const ui = @import("nanoui").ui;

pub const dark: ui.Theme = .{
    .dark = true,
    .background = .hex(0x181819),
    .surface = .hex(0x1f2021),
    .surface_hover = .hex(0x26282a),
    .text = .hex(0xe0e2e4),
    .muted = .hex(0x9ba0a2),
    .border = .hex(0x2e3033),
    .accent = .hex(0x40d2c3),
    .accent_hover = .hex(0x63e0d3),
    .accent_text = .hex(0x06201d),
    .track = .hex(0x2a2c2e),
    .knob = .hex(0xe0e2e4),
    .danger = .hex(0xf0736e),
    .success = .hex(0x6fd08c),
    .shadow = .{ .a = 0 },
};

pub const light: ui.Theme = .{
    .dark = false,
    .background = .hex(0xebeae7),
    .surface = .hex(0xf7f6f3),
    .surface_hover = .hex(0xe2e0da),
    .text = .hex(0x1f2321),
    .muted = .hex(0x6c716f),
    .border = .hex(0xd3d1cb),
    .accent = .hex(0x2f7d75),
    .accent_hover = .hex(0x266962),
    .accent_text = .hex(0xffffff),
    .track = .hex(0xdedcd6),
    .knob = .hex(0xffffff),
    .danger = .hex(0xc0453e),
    .success = .hex(0x2c7a4b),
    .shadow = .{ .a = 0 },
};

/// The soft yellow a highlight is drawn with.
pub fn highlightColor(dark_mode: bool) ui.Color {
    return if (dark_mode) .hex(0xe8c55c) else .hex(0xf6ebaa);
}

pub fn pick(dark_mode: bool) ui.Theme {
    return if (dark_mode) dark else light;
}

/// A ruler line's colour between pages.
pub fn rule(th: ui.Theme) ui.Color {
    return th.border;
}

/// The colour of a status message.
pub fn statusColor(th: ui.Theme, kind: enum { plain, good, bad, busy }) ui.Color {
    return switch (kind) {
        .plain => th.muted,
        .good => th.success,
        .bad => th.danger,
        .busy => th.accent,
    };
}
