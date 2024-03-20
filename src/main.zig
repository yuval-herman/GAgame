const std = @import("std");
const ui = @import("ui.zig");
const Player = ui.Player;

const r = @import("cHeaders.zig").raylib;
const Creature = @import("creature.zig").Creature;

const G = @import("global_state.zig");

const assert = std.debug.assert;

const EVALUATION_TICKS = 60 * 15;

const MUTATION_RATE = 0.3;
const IND_MUTATION_RATE = 0.01;

const POPULATION_SIZE = 1000;
const HOF_SIZE = 1;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

pub fn main() !void {
    assert(HOF_SIZE < POPULATION_SIZE);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

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
    var evolve_toggle = false;
    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        if (r.IsKeyPressed(r.KEY_SPACE)) {
            evolve_toggle = !evolve_toggle;
        }
        if (evolve_toggle) {
            try G.app_state.best_history.append(try evolve(&pop));

            var avg_edges: usize = 0;
            var avg_nodes: usize = 0;
            for (pop) |cs| {
                avg_edges += cs.edges.items.len;
                avg_nodes += cs.nodes.items.len;
            }
            avg_edges /= pop.len;
            avg_nodes /= pop.len;

            const avg = G.app_state.best_history.items[gen].getAvgPos();
            std.debug.print("gen: {}, t_size: {}, best avg: ({d:.2}, {d:.2}), best fitness:{d:.2}, edges: {}, nodes: {}\n", .{
                gen,
                G.app_state.tournament_size,
                avg[0],
                avg[1],
                pop[0].fitness,
                avg_edges,
                avg_nodes,
            });
            gen += 1;

            G.app_state.tournament_size = @min(POPULATION_SIZE / 2, @max(POPULATION_SIZE / 10, gen * gen / POPULATION_SIZE));
        }
        if (gen != 0) {
            try Player.draw();
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

    for (pop[HOF_SIZE..]) |*c| {
        c.evaluate(EVALUATION_TICKS, G.app_state.GRAVITY, G.RELAX_GRAPH_ITERS, G.app_state.GROUND_LEVEL, G.app_state.DAMPING);
    }
    std.mem.sort(Creature, pop, {}, creatureComp);

    return try pop[0].clone();
}
