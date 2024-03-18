const r = @import("cHeaders.zig").raylib;
const std = @import("std");
const assert = std.debug.assert;
const bufPrint = std.fmt.bufPrint;

const SCREEN_WIDTH = 1000;
const SCREEN_HEIGHT = 500;
const GROUND_LEVEL = SCREEN_HEIGHT / 2 - 100;
var fps: c_int = 10;

const GRAVITY = 0.5;
const DAMPING = 0.99;

const EVALUATION_TICKS = 60 * 15;
const RELAX_GRAPH_ITERS = 100;

const SELECTION_RATE = 6;
const MUTATION_RATE = 0.3;
const IND_MUTATION_RATE = 0.3;

const POPULATION_SIZE = 1000;
const GENERATIONS = 100;
const HOF_SIZE = 1;

const Creature = @import("creature.zig").init(GROUND_LEVEL, GRAVITY, DAMPING, RELAX_GRAPH_ITERS);
var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();
var textBuffer: [10000]u8 = undefined;
const Timer = std.time.Timer;

pub fn main() !void {
    r.SetTraceLogLevel(r.LOG_WARNING);
    assert(HOF_SIZE < POPULATION_SIZE);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(fps);

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
        c.* = try Creature.createRandom(random.intRangeAtMost(usize, 3, 5), random.float(f32), allocator);
    }

    var t = try Timer.start();
    const Timings = struct {
        evaluate: u64 = 0,
        mutate: u64 = 0,
        crossover: u64 = 0,
    };
    var timings = Timings{};

    for (0..GENERATIONS) |gen| {
        t.reset();
        for (pop[HOF_SIZE..]) |*c| {
            c.evaluate(EVALUATION_TICKS);
        }
        timings.evaluate += t.read();

        std.mem.sort(Creature, &pop, {}, creatureComp);
        best_history[gen] = try pop[0].clone();

        var avg_edges: usize = 0;
        var avg_nodes: usize = 0;
        for (pop) |cs| {
            avg_edges += cs.edges.items.len;
            avg_nodes += cs.nodes.items.len;
        }
        avg_edges /= pop.len;
        avg_nodes /= pop.len;

        const avg = pop[0].getAvgPos();
        std.debug.print("gen: {}, best avg: ({d:.2}, {d:.2}), best fitness:{d:.2}, edges: {}, nodes: {}\n", .{ gen, avg[0], avg[1], pop[0].fitness, avg_edges, avg_nodes });

        for (&newPop) |*nc| {
            const a = random.intRangeLessThan(usize, 0, pop.len / SELECTION_RATE);
            var b = a;
            while (a == b) b = random.intRangeLessThan(usize, 0, pop.len / SELECTION_RATE);
            t.reset();
            nc.* = try pop[a].crossover(pop[b]);
            timings.crossover += t.lap();
            if (random.float(f32) < MUTATION_RATE) try nc.mutate(IND_MUTATION_RATE);
            timings.mutate += t.read();
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
    std.debug.print("evaluate: {d:.2} crossover: {d:.2} mutate: {d:.2}\n", .{
        @as(f64, @floatFromInt(timings.evaluate)) * 1e-9,
        @as(f64, @floatFromInt(timings.crossover)) * 1e-9,
        @as(f64, @floatFromInt(timings.mutate)) * 1e-9,
    });
    var camera = r.Camera2D{
        .zoom = 1,
        .offset = .{ .x = SCREEN_WIDTH / 2, .y = SCREEN_HEIGHT / 2 },
    };
    var c: Creature = undefined;
    var cI: usize = 0;
    var changeC = true;

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        if ((r.IsKeyPressed(r.KEY_RIGHT) or r.IsKeyDown(r.KEY_RIGHT)) and cI < best_history.len - 1) {
            cI += 1;
            changeC = true;
        }
        if ((r.IsKeyPressed(r.KEY_LEFT) or r.IsKeyDown(r.KEY_LEFT)) and cI >= 1) {
            cI -= 1;
            changeC = true;
        }
        if (r.IsKeyDown(r.KEY_DOWN) and fps > 1) {
            fps -= 1;
            r.SetTargetFPS(fps);
        }
        if (r.IsKeyDown(r.KEY_UP) and fps < std.math.maxInt(c_int)) {
            fps += 1;
            r.SetTargetFPS(fps);
        }
        if (r.IsKeyDown(r.KEY_END)) {
            cI = best_history.len - 1;
            changeC = true;
        }
        if (r.IsKeyDown(r.KEY_HOME)) {
            cI = 0;
            changeC = true;
        }
        if (changeC) {
            changeC = false;
            c = best_history[cI];
            const avg = c.getAvgPos();
            std.debug.print("cI: {} avg: ({d:.2}, {d:.2})\n", .{ cI, avg[0], avg[1] });
            c.resetValues();
        }
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        r.BeginMode2D(camera);

        var text_buffer_idx: usize = 0;
        var text_slice: []u8 = undefined;
        for (0..200) |i| {
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

        var center_pos: @Vector(2, f32) = @splat(0);
        var farthest_pos: @Vector(2, f32) = c.nodes.items[0].pos;
        for (c.nodes.items) |n| {
            center_pos += n.pos;
            if (n.pos[0] < farthest_pos[0]) farthest_pos = n.pos;
        }
        center_pos /= @splat(@floatFromInt(c.nodes.items.len));
        camera.target.x = center_pos[0];
        camera.target.y = center_pos[1];
        camera.zoom = @min(1, SCREEN_WIDTH / ((center_pos[0] - farthest_pos[0]) * 2));

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
        text_slice = try bufPrint(textBuffer[text_buffer_idx..], "fps {d:.2}", .{1 / r.GetFrameTime()});
        text_buffer_idx += text_slice.len + 1; // add one to account for c-style null termination.

        r.DrawText(
            @ptrCast(text_slice),
            0,
            50,
            20,
            r.BLACK,
        );
        r.EndDrawing();
        @memset(text_slice, 0);
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
