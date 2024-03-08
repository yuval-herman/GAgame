const r = @import("cHeaders.zig").raylib;
const std = @import("std");
const Allocator = std.mem.Allocator;

const screenWidth = 1920;
const screenHeight = 450;
const groundLevel = screenHeight / 2;
const gravity = 0.2;
const FPS = 60;

var buffer: [1000000]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const allocator = fba.allocator();
const creatures = @import("creature.zig").init(groundLevel, gravity, allocator);

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

pub fn main() !void {
    var textBuffer: [500]u8 = undefined;

    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(screenWidth, screenHeight, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(FPS);

    var camera = r.Camera2D{
        .zoom = 1,
        .offset = .{ .x = screenWidth / 2, .y = screenHeight / 2 },
    };

    var pop: [100]creatures.Creature = undefined;
    var farthest: *creatures.Creature = &pop[0];
    for (&pop) |*c| {
        c.* = try creatures.makeRandomCreature(3);
    }

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        const farthest_Pos = farthest.getAvgPos();
        camera.target = farthest_Pos;
        r.BeginMode2D(camera);
        for (&pop) |*c| {
            const avgPos = c.getAvgPos();
            if (avgPos.x > farthest_Pos.x) {
                farthest = c;
            }
            r.DrawText(@ptrCast(try std.fmt.bufPrintZ(&textBuffer, "{d:.2}", .{avgPos.x})), @intFromFloat(avgPos.x), @intFromFloat(avgPos.y - 100), 10, r.BLACK);
            c.tick();
            c.draw();
        }
        // Draw ground
        r.DrawRectangle(@intFromFloat(camera.target.x - camera.offset.x - 100), groundLevel, screenWidth + 200, screenHeight, r.BLACK);
        r.EndMode2D();
        r.EndDrawing();
    }
}
