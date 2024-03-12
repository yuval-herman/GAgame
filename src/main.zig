const r = @import("cHeaders.zig").raylib;
const std = @import("std");

const screenWidth = 1000;
const screenHeight = 500;
var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

pub fn main() !void {
    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(screenWidth, screenHeight, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(60);

    const camera = r.Camera2D{
        .zoom = 1,
        .offset = .{ .x = screenWidth / 2, .y = screenHeight / 2 },
    };

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        r.BeginMode2D(camera);

        r.EndMode2D();
        r.EndDrawing();
    }
}
