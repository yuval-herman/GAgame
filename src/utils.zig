const std = @import("std");
const r = @import("cHeaders.zig").raylib;

pub fn v2FromVector(vector: @Vector(2, f32)) r.Vector2 {
    return .{ .x = vector[0], .y = vector[1] };
}
