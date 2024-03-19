const std = @import("std");
const Creature = @import("creature.zig").Creature;

pub const RELAX_GRAPH_ITERS = 100;

pub const GlobalState = struct {
    best_history: std.ArrayList(Creature),
    SCREEN_WIDTH: c_int,
    SCREEN_HEIGHT: c_int,
    GROUND_LEVEL: f32,
    DAMPING: @Vector(2, f32),
    GRAVITY: f32,
    fps: c_int,
};

var buf: [1000000]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);

pub var app_state = GlobalState{
    .best_history = std.ArrayList(Creature).init(fba.allocator()),
    .SCREEN_WIDTH = 1000,
    .SCREEN_HEIGHT = 500,
    .GROUND_LEVEL = 0,
    .DAMPING = @splat(0.9),
    .GRAVITY = 1,
    .fps = 30,
};
