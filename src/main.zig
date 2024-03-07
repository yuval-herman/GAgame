const r = @import("cHeaders.zig").raylib;
const std = @import("std");
const Allocator = std.mem.Allocator;

const screenWidth = 800;
const screenHeight = 450;
const groundLevel = screenHeight / 2;
const gravity = 0.2;

const creatures = @import("creature.zig").init(groundLevel, gravity);

pub fn main() !void {
    var buffer: [100000]u8 = undefined;
    // var textBuffer: [500]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(screenWidth, screenHeight, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(60);

    var population: [100]creatures.Creature = undefined;
    for (&population) |*c| {
        c.* = try creatures.makeRandomCreature(3, allocator);
    }
    defer {
        for (&population) |*c| {
            c.deinit(allocator);
        }
    }

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);

        for (&population) |*c| {
            c.tick();
            c.draw();
        }

        // Draw ground
        r.DrawRectangle(0, groundLevel, screenWidth, screenHeight, r.BLACK);

        r.EndDrawing();
    }
}
// r.DrawText(@ptrCast(try std.fmt.bufPrintZ(&textBuffer, "creature reached {d} position", .{averagePos})), 0, 0, 20, r.LIGHTGRAY);
