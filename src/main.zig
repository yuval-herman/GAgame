const r = @import("cHeaders.zig").raylib;
const std = @import("std");
const bufPrint = std.fmt.bufPrint;

const SCREEN_WIDTH = 1000;
const SCREEN_HEIGHT = 500;
const GROUND_LEVEL = SCREEN_HEIGHT - 100;
const GRAVITY = 1;
const DAMPING = 0.99;

const Creature = @import("creature.zig").init(GROUND_LEVEL, GRAVITY, DAMPING);
var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();
var textBuffer: [1000]u8 = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(60);

    var camera = r.Camera2D{
        .zoom = 1,
        .offset = .{ .x = SCREEN_WIDTH / 2, .y = SCREEN_HEIGHT / 2 },
    };

    var c: Creature = try Creature.createRandom(4, 0.5, allocator);

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        r.BeginMode2D(camera);

        var text_buffer_idx: usize = 0;
        for (0..100) |i| {
            const font_size = 30;
            var sign = r.Rectangle{
                .x = @floatFromInt(i * 250),
                .y = GROUND_LEVEL - 150,
                .height = 50,
                .width = undefined,
            };
            const text_slice = try bufPrint(textBuffer[text_buffer_idx..], "{d:.1}", .{sign.x / 100});
            text_buffer_idx += text_slice.len + 1; // add one to account for c-style null termination.
            const text: [*c]u8 = @ptrCast(text_slice);
            const text_width: f32 = @floatFromInt(r.MeasureText(text, font_size));
            sign.width = @max(100, text_width + 20);
            r.DrawRectangleRec(sign, r.LIGHTGRAY);
            r.DrawText(
                text,
                @intFromFloat(sign.x + sign.width / 2 - text_width / 2),
                @intFromFloat(sign.y + sign.height / 2 - font_size / 2),
                font_size,
                r.BLACK,
            );
        }

        // c.mutate();
        c.tick();
        c.draw();

        camera.target.x = 0;
        for (c.nodes.items) |n| {
            camera.target.x += n.pos.x;
        }
        camera.target.x /= @floatFromInt(c.nodes.items.len);

        camera.target.y = GROUND_LEVEL;

        r.DrawRectangle(@intFromFloat(camera.target.x - SCREEN_WIDTH), GROUND_LEVEL, SCREEN_WIDTH * 2, 500, r.BLACK);

        r.EndMode2D();
        r.EndDrawing();
    }
}

fn creatureComp(context: void, a: Creature, b: Creature) bool {
    _ = context;
    return a.fitness > b.fitness;
}
