const r = @import("cHeaders.zig").raylib;
const std = @import("std");
const Physics = @import("physics/particle.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const screenWidth = 800;
const screenHeight = 450;
const groundLevel = screenHeight / 2;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

const gravity = 0.2;

const Particle = Physics.initParticleStruct(groundLevel, gravity);
const Spring = Physics.initParticleSpring(groundLevel, gravity);

pub fn main() !void {
    // var buffer: [10000]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // const allocator = fba.allocator();
    // r.DrawText(@ptrCast(try std.fmt.bufPrintZ(&buffer, "{any}", .{c})), 0, 0, 20, r.LIGHTGRAY);

    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(screenWidth, screenHeight, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(60);

    var p1 = Particle{
        .pos = .{
            .x = screenWidth / 2 - 100,
            .y = 300,
        },
    };
    var p2 = Particle{
        .pos = .{
            .x = screenWidth / 2,
            .y = 0,
        },
    };
    var p3 = Particle{
        .pos = .{
            .x = screenWidth / 2 + 100,
            .y = 300,
        },
    };
    var springs = [_]Spring{
        .{ .particals = .{ &p1, &p2 }, .k = 0.05 },
        .{ .particals = .{ &p2, &p3 }, .k = 0.05 },
        .{ .particals = .{ &p3, &p1 }, .k = 0.05 },
    };

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        for (&springs) |*s| {
            s.tick();
            s.draw();
        }

        // Draw ground
        r.DrawRectangle(0, groundLevel, screenWidth, screenHeight, r.BLACK);

        r.EndDrawing();
    }
}
