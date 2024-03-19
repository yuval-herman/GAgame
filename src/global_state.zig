const Creature = @import("creature.zig").Creature;

pub const GENERATIONS = 10;
pub const RELAX_GRAPH_ITERS = 100;

pub const GlobalState = struct {
    best_history: [GENERATIONS]Creature,
    SCREEN_WIDTH: c_int,
    SCREEN_HEIGHT: c_int,
    GROUND_LEVEL: f32,
    DAMPING: @Vector(2, f32),
    GRAVITY: f32,
    fps: c_int,
};

pub var app_state = GlobalState{
    .best_history = undefined,
    .SCREEN_WIDTH = 1000,
    .SCREEN_HEIGHT = 500,
    .GROUND_LEVEL = 0,
    .DAMPING = @splat(0.9),
    .GRAVITY = 1,
    .fps = 10,
};
