const std = @import("std");
const Thread = std.Thread;

const ui = @import("ui.zig");

const r = @import("cHeaders.zig").raylib;
const Creature = @import("creature.zig").Creature;

const G = @import("global_state.zig");

const assert = std.debug.assert;

const EVALUATION_TICKS = 60 * 30;

const MUTATION_RATE = 0.25;
const IND_MUTATION_RATE = 0.02;

const POPULATION_SIZE = 1000;
const HOF_SIZE = 1;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

var waitGroup = Thread.WaitGroup{};
var pool: Thread.Pool = undefined;

var evolve_toggle = Thread.ResetEvent{};

pub fn main() !void {
    assert(HOF_SIZE < POPULATION_SIZE);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try pool.init(.{ .allocator = allocator });
    defer pool.deinit();

    r.SetTraceLogLevel(r.LOG_WARNING);
    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(G.app_state.SCREEN_WIDTH, G.app_state.SCREEN_HEIGHT, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(G.app_state.fps);

    var pop: [POPULATION_SIZE]Creature = undefined;

    for (&pop) |*c| {
        c.* = try Creature.createRandom(random.intRangeAtMost(usize, 3, 5), random.float(f32), allocator);
        c.evaluate(EVALUATION_TICKS, G.app_state.GRAVITY, G.RELAX_GRAPH_ITERS, G.app_state.GROUND_LEVEL, G.app_state.DAMPING);
    }
    std.mem.sort(Creature, &pop, {}, creatureComp);

    var gen: usize = 0;

    try G.app_state.best_history.append(try evolve(&pop));
    gen += 1;

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);

        switch (G.app_state.screen) {
            .configs => {
                ui.Configs.draw();
            },
            .player => {
                if (r.IsKeyPressed(r.KEY_SPACE)) {
                    if (evolve_toggle.isSet()) {
                        evolve_toggle.reset();
                    } else {
                        evolve_toggle.set();
                        var thread = try Thread.spawn(.{ .allocator = allocator }, workerEvolve, .{ &pop, &gen });
                        thread.detach();
                    }
                }
                try ui.Player.draw();
            },
        }
        r.EndDrawing();
    }
}

fn workerEvolve(pop: []Creature, gen: *usize) !void {
    while (evolve_toggle.isSet()) {
        try G.app_state.best_history.append(try evolve(pop));

        var avg_edges: usize = 0;
        var avg_nodes: usize = 0;
        for (pop) |cs| {
            avg_edges += cs.edges.items.len;
            avg_nodes += cs.nodes.items.len;
        }
        avg_edges /= pop.len;
        avg_nodes /= pop.len;

        const avg = G.app_state.best_history.items[gen.*].getAvgPos();
        std.debug.print("gen: {}, t_size: {}, best avg: ({d:.2}, {d:.2}), best fitness:{d:.2}, edges: {}, nodes: {}\n", .{
            gen.*,
            G.app_state.tournament_size,
            avg[0],
            avg[1],
            pop[0].fitness,
            avg_edges,
            avg_nodes,
        });
        gen.* += 1;

        var bests = G.app_state.best_history.items;
        if (bests.len > 10) {
            bests = bests[bests.len - 10 ..];
        }

        const first_fitness = bests[0].fitness;
        const all_equal = for (bests) |b|
            (if (b.fitness != first_fitness) break false)
        else
            true;
        if (all_equal) {
            G.app_state.tournament_size = @max(@max(2, POPULATION_SIZE / 10), G.app_state.tournament_size - 1);
        } else {
            G.app_state.tournament_size = @min(POPULATION_SIZE / 2, G.app_state.tournament_size + 5);
        }
    }
}

fn creatureComp(context: void, a: Creature, b: Creature) bool {
    _ = context;
    return a.fitness > b.fitness;
}

fn select(pop: []Creature) [2]Creature {
    var max_participants: [POPULATION_SIZE]usize = undefined;
    const participants = max_participants[0..G.app_state.tournament_size];

    for (participants) |*participant| {
        participant.* = random.intRangeLessThan(usize, 0, pop.len);
    }
    std.mem.sort(usize, participants, {}, std.sort.desc(usize));
    return .{ pop[participants[0]], pop[participants[1]] };
}

fn evolve(pop: []Creature) !Creature {
    var newPop: [POPULATION_SIZE]Creature = undefined;

    for (&newPop) |*nc| {
        const selected = select(pop);
        nc.* = try selected[0].crossover(selected[1]);
        if (random.float(f32) < MUTATION_RATE) try nc.mutate(IND_MUTATION_RATE);
    }

    for (pop[HOF_SIZE..]) |*c| {
        c.deinit();
    }
    @memcpy(pop[HOF_SIZE..], newPop[0 .. pop.len - HOF_SIZE]);
    waitGroup.reset();
    for (pop[HOF_SIZE..]) |*c| {
        waitGroup.start();
        try pool.spawn(workerEvaluate, .{ c, &waitGroup });
    }
    pool.waitAndWork(&waitGroup);

    std.mem.sort(Creature, pop, {}, creatureComp);

    return try pop[0].clone();
}

fn workerEvaluate(c: *Creature, wg: *Thread.WaitGroup) void {
    defer wg.finish();
    c.evaluate(EVALUATION_TICKS, G.app_state.GRAVITY, G.RELAX_GRAPH_ITERS, G.app_state.GROUND_LEVEL, G.app_state.DAMPING);
}
