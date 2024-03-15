const r = @import("cHeaders.zig").raylib;
const std = @import("std");
const assert = std.debug.assert;
const bufPrint = std.fmt.bufPrint;

const SCREEN_WIDTH = 1000;
const SCREEN_HEIGHT = 500;
const GROUND_LEVEL = SCREEN_HEIGHT - 100;
const GRAVITY = 0.1;
const DAMPING = 0.99;
const EVALUATION_TICKS = 60 * 10;
const SELECTION_RATE = 5;
const MUTATION_RATE = 0.2;
const IND_MUTATION_RATE = 0.5;
const GENERATIONS = 10;
const RELAX_GRAPH_ITERS = 100;
const POPULATION_SIZE = 1000;
const HOF_SIZE = 5;

const Creature = @import("creature.zig").init(GROUND_LEVEL, GRAVITY, DAMPING, RELAX_GRAPH_ITERS);
var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();
var textBuffer: [1000]u8 = undefined;

pub fn main() !void {
    r.SetTraceLogLevel(r.LOG_WARNING);
    assert(HOF_SIZE < POPULATION_SIZE);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(60);

    var pop: [POPULATION_SIZE]Creature = undefined;
    var newPop: [pop.len]Creature = undefined;
    defer {
        for (&newPop) |*c| {
            c.deinit();
        }
    }
    var best_history: [GENERATIONS]Creature = undefined;
    defer {
        for (&best_history) |*c| {
            c.deinit();
        }
    }
    for (&pop) |*c| {
        c.* = try Creature.createRandom(random.intRangeAtMost(usize, 2, 5), random.float(f32), allocator);
    }

    for (0..GENERATIONS) |gen| {
        for (pop[HOF_SIZE..]) |*c| {
            c.evaluate(EVALUATION_TICKS);
        }
        std.mem.sort(Creature, &pop, {}, creatureComp);
        best_history[gen] = try pop[0].clone();

        const avg = pop[0].getAvgPos();
        var avg_edges: usize = 0;
        var avg_nodes: usize = 0;
        for (pop) |cs| {
            avg_edges += cs.edges.items.len;
            avg_nodes += cs.nodes.items.len;
        }
        avg_edges /= pop.len;
        avg_nodes /= pop.len;
        std.debug.print("gen: {}, best avg: ({d:.2}, {d:.2}), edges: {}, nodes: {}\n", .{ gen, avg.x, avg.y, avg_nodes, avg_edges });

        for (&newPop) |*nc| {
            const a = random.intRangeLessThan(usize, 0, pop.len / SELECTION_RATE);
            var b = a;
            while (a == b) b = random.intRangeLessThan(usize, 0, pop.len / SELECTION_RATE);
            nc.* = try pop[a].crossover(pop[b]);

            if (random.float(f32) < MUTATION_RATE) try nc.mutate(IND_MUTATION_RATE);
        }

        for (pop[HOF_SIZE..]) |*c| {
            c.deinit();
        }
        @memcpy(pop[HOF_SIZE..], newPop[0 .. pop.len - HOF_SIZE]);
    }
    for (&pop) |*c| {
        c.evaluate(EVALUATION_TICKS);
    }
    std.mem.sort(Creature, &pop, {}, creatureComp);

    var camera = r.Camera2D{
        .zoom = 1,
        .offset = .{ .x = SCREEN_WIDTH / 2, .y = SCREEN_HEIGHT / 2 },
    };
    var c: Creature = undefined;
    var timer: u16 = 0;
    var cI: usize = GENERATIONS - 10;
    var changeC = false;

    while (!r.WindowShouldClose()) : (timer +%= 1) // Detect window close button or ESC key
    {
        if (r.IsKeyPressed(r.KEY_RIGHT) and cI < best_history.len - 1) {
            cI += 1;
            changeC = true;
            timer = 1;
        }
        if (r.IsKeyPressed(r.KEY_LEFT) and cI >= 1) {
            cI -= 1;
            changeC = true;
            timer = 1;
        }
        if (timer % (EVALUATION_TICKS) == 0) {
            changeC = true;
            cI = (cI + 1) % (best_history.len - 1);
        }
        if (changeC) {
            changeC = false;
            c = best_history[cI];
            const avg = c.getAvgPos();
            std.debug.print("timer: {}, cI: {} avg: ({d:.2}, {d:.2})\n", .{ timer, cI, avg.x, avg.y });
            c.resetValues();
        }
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        r.BeginMode2D(camera);

        var text_buffer_idx: usize = 0;
        var text_slice: []u8 = undefined;
        for (0..100) |i| {
            const font_size = 30;
            var sign = r.Rectangle{
                .x = @floatFromInt(i * 250),
                .y = GROUND_LEVEL - 150,
                .height = 50,
                .width = undefined,
            };
            text_slice = try bufPrint(textBuffer[text_buffer_idx..], "{d:.1}", .{sign.x / 100});
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

        c.tick();
        c.draw();

        camera.target = c.getAvgPos();

        text_slice = try bufPrint(textBuffer[text_buffer_idx..], "{d:.1}", .{camera.target.x});
        text_buffer_idx += text_slice.len + 1; // add one to account for c-style null termination.

        r.DrawText(
            @ptrCast(text_slice),
            @intFromFloat(camera.target.x),
            @intFromFloat(camera.target.y - 200),
            20,
            r.BLACK,
        );

        r.DrawRectangle(@intFromFloat(camera.target.x - SCREEN_WIDTH), GROUND_LEVEL, SCREEN_WIDTH * 2, 500, r.BLACK);

        r.EndMode2D();
        r.EndDrawing();
    }
}

fn creatureComp(context: void, a: Creature, b: Creature) bool {
    _ = context;
    return a.fitness > b.fitness;
}

const testing = std.testing;
test "memory leaks" {
    var a = try Creature.createRandom(4, 0.5, testing.allocator);
    var b = try Creature.createRandom(4, 0.5, testing.allocator);
    var c = try a.crossover(b);

    defer a.deinit();
    defer b.deinit();
    defer c.deinit();

    var arr: [10]Creature = undefined;
    var arr2: [10]Creature = undefined;
    for (&arr) |*d| {
        d.* = try Creature.createRandom(4, 0.5, testing.allocator);
    }
    for (0..3) |_| {
        for (&arr2) |*d| {
            d.* = try arr[0].crossover(arr[1]);
        }
        for (&arr) |*d| {
            d.deinit();
        }
        arr = arr2;
    }

    for (&arr2) |*d| {
        d.deinit();
    }
}
