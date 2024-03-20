const std = @import("std");
const r = @import("../../cHeaders.zig").raylib;
const G = @import("../../global_state.zig");

const Button = @import("../components/button.zig");
const TextInput = @import("../components/textInput.zig");

var buf: [10]u8 = undefined;
var input = TextInput{
    .pos = r.Vector2{},
    .textBuf = &buf,
};
var play_button = Button{
    .text = "play",
    .action = click_play,
    .pos = .{
        .x = 0,
        .y = 0,
    },
};
pub fn draw() void {
    input.draw();

    play_button.pos.x = @as(f32, @floatFromInt(G.app_state.SCREEN_WIDTH)) / 2;
    play_button.pos.y = @as(f32, @floatFromInt(G.app_state.SCREEN_HEIGHT)) / 2;
    play_button.draw();
}

fn click_play() void {
    G.app_state.screen = G.Screens.player;
}
