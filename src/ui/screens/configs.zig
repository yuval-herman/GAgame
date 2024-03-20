const std = @import("std");
const r = @import("../../cHeaders.zig").raylib;
const G = @import("../../global_state.zig");

const Button = @import("../components/button.zig");
const TextInput = @import("../components/textInput.zig");
const Label = @import("../components/label.zig");

var mem_buffer: [10000]u8 = undefined;

var gravity_label = Label{ .text = "Gravity", .x = undefined, .y = undefined };
var gravity_input = TextInput{
    .pos = r.Vector2{},
    .textBuf = mem_buffer[0..15],
};

var play_button = Button{
    .text = "play",
    .action = click_play,
    .pos = undefined,
};

pub fn draw() void {
    const f_scr_wid: f32 = @floatFromInt(G.app_state.SCREEN_WIDTH);
    const f_scr_hig: f32 = @floatFromInt(G.app_state.SCREEN_HEIGHT);
    const i_scr_wid = G.app_state.SCREEN_WIDTH;
    const i_scr_hig = G.app_state.SCREEN_HEIGHT;

    gravity_label.x = @divFloor(i_scr_wid, 10);
    gravity_label.y = @divFloor(i_scr_hig, 10);
    gravity_input.pos.x = @floatFromInt(gravity_label.x + 100);
    gravity_input.pos.y = @floatFromInt(gravity_label.y - @divFloor(gravity_label.font_size, 2));

    gravity_label.draw();
    gravity_input.draw();

    play_button.pos.x = f_scr_wid / 2;
    play_button.pos.y = f_scr_hig / 2;
    play_button.draw();
}

fn click_play() void {
    G.app_state.GRAVITY = std.fmt.parseFloat(f32, gravity_input.getText()) catch G.app_state.GRAVITY;
    G.app_state.screen = G.Screens.player;
}
