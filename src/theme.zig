//! Flat dark theme for revise: 1px divider lines, rectangular corners,
//! no shadows, one accent colour. Built on nanoui's Theme.dark_theme.
const ui = @import("nanoui").ui;

pub const theme: ui.Theme = .{
    .dark = true,
    .background = .hex(0x1c1c1e),
    .surface = .hex(0x252526),
    .surface_hover = .hex(0x3a3a3c),
    .text = .hex(0xeaeaea),
    .muted = .hex(0x98989d),
    .border = .hex(0x48484a),
    .accent = .hex(0x0a84ff),
    .accent_hover = .hex(0x409cff),
    .accent_text = .white,
    .track = .hex(0x48484a),
    .knob = .hex(0xf5f5f7),
    .danger = .hex(0xff453a),
    .success = .hex(0x30d158),
    .shadow = .{ .a = 0 },
};
