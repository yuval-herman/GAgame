const r = @import("cHeaders.zig").raylib;
const std = @import("std");
const Allocator = std.mem.Allocator;

const screenWidth = 800;
const screenHeight = 450;
const groundLevel = screenHeight / 2;
const gravity = 0.2;

const creatures = @import("creature.zig").init(groundLevel, gravity);

pub fn main() !void {
    var buffer: [10000]u8 = undefined;
    var textBuffer: [500]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(screenWidth, screenHeight, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(60);

    var c = try creatures.makeRandomCreature(3, allocator);
    defer c.deinit(allocator);

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);

        c.tick();

        var averagePos: f32 = 0;
        for (c.joints) |joint| {
            averagePos += joint.pos.x;
        }
        averagePos /= @floatFromInt(c.joints.len);

        c.draw();
        r.DrawText(@ptrCast(try std.fmt.bufPrintZ(&textBuffer, "creature reached {d} position", .{averagePos})), 0, 0, 20, r.LIGHTGRAY);
        // Draw ground
        r.DrawRectangle(0, groundLevel, screenWidth, screenHeight, r.BLACK);

        r.EndDrawing();
    }
}
