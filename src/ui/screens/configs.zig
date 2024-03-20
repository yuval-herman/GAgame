const std = @import("std");
const r = @import("../../cHeaders.zig").raylib;
const G = @import("../../global_state.zig");

const Button = @import("../components/buttons.zig");

var play_button = Button{
    .text = "play",
    .action = click_play,
    .pos = .{
        .x = 0,
        .y = 0,
    },
};
pub fn draw() void {
    play_button.pos.x = @divFloor(G.app_state.SCREEN_WIDTH, 2);
    play_button.pos.y = @divFloor(G.app_state.SCREEN_HEIGHT, 2);
    play_button.draw();
}

fn click_play() void {
    G.app_state.screen = G.Screens.player;
}
