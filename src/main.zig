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
    // var textBuffer: [500]u8 = undefined;

    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(screenWidth, screenHeight, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(FPS);

    var c1 = try creatures.makeRandomCreature(3);
    for (0..1000000) |_| {
        try creatures.mutateCreature(&c1, 1);
    }

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);

        c1.tick();
        c1.draw();

        // Draw ground
        r.DrawRectangle(0, groundLevel, screenWidth, screenHeight, r.BLACK);

        r.EndDrawing();
    }
}

// r.DrawText(@ptrCast(try std.fmt.bufPrintZ(&textBuffer, "creature reached {d} position", .{averagePos})), 0, 0, 20, r.LIGHTGRAY);
