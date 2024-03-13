const r = @import("cHeaders.zig").raylib;
const std = @import("std");

const SCREEN_WIDTH = 1000;
const SCREEN_HEIGHT = 500;
const GROUND_LEVEL = SCREEN_HEIGHT - 100;
const GRAVITY = 1;
const DAMPING = 0.99;

const Creature = @import("creature.zig").init(GROUND_LEVEL, GRAVITY, DAMPING);
var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

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

    var pop: [1000]Creature = undefined;
    for (&pop) |*c| {
        c.* = try Creature.createRandom(
            random.intRangeAtMost(usize, 2, 10),
            random.float(f32),
            allocator,
        );
    }

    for (&pop) |*c| {
        for (0..1000) |_| {
            c.tick();
        }
    }

    var fc: Creature = pop[0];
    var fp = fc.getFarthestNodePos().x;
    for (pop) |c| {
        const cfp = c.getFarthestNodePos().x;
        if (cfp <= fp) continue;
        fp = cfp;
        fc = c;
    }
    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        r.BeginMode2D(camera);
        fc.tick();
        fc.draw();
        camera.target = fc.nodes.items[0].pos;

        r.DrawRectangle(@intFromFloat(camera.target.x - SCREEN_WIDTH / 2 - 10), GROUND_LEVEL, SCREEN_WIDTH + 20, 500, r.BLACK);
        r.EndMode2D();
        r.EndDrawing();
    }
}
