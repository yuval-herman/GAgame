const std = @import("std");
const utils = @import("utils.zig");

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

var c_prng = std.Random.DefaultPrng.init(0);
const c_random = c_prng.random();

const ArrayList = std.ArrayList;

const random_values = struct {
    fn seed() u64 {
        return random.int(u64);
    }
    fn elasticity() f32 {
        return random.float(f32);
    }
    fn friction() f32 {
        return random.float(f32);
    }
    fn strength() f32 {
        return random.float(f32) * 2;
    }
    fn long_length() f32 {
        return random.float(f32) * 200 + 10;
    }
    fn short_length() f32 {
        return long_length();
    }
    fn long_time() u8 {
        return random.intRangeAtMost(u8, 1, std.math.maxInt(u8));
    }
    fn short_time() u8 {
        return long_time();
    }
};

pub const Node = struct {
    pub const radius = 10;

    pos: @Vector(2, f32) = @splat(0),
    velocity: @Vector(2, f32) = @splat(0),
    elasticity: f32,
    friction: f32,
    onGround: bool = false,

    pub fn isGrounded(self: Node, ground_level: f32) bool {
        return self.pos[1] + Node.radius >= ground_level;
    }
};
const Muscle = struct {
    nodes: [2]usize,
    strength: f32,
    long_length: f32,
    short_length: f32,
    long_time: u8,
    short_time: u8,
    is_long: bool = false,
};

pub const Creature = struct {
    nodes: ArrayList(Node),
    edges: ArrayList(Muscle),
    clock: u8 = 0,
    fitness: f64 = 0,
    seed: u64,

    pub fn tick(self: *Creature, ground_level: f32, gravity: f32, damping: @Vector(2, f32)) void {
        self.clock +%= 1;
        for (self.nodes.items) |*node| {
            node.pos += node.velocity;
            node.velocity *= damping;
            if (node.isGrounded(ground_level)) {
                node.pos[1] = ground_level - Node.radius + 1; // can't be the exact ground position because of rounding errors
                node.velocity[0] *= node.friction;
                if (!node.onGround) node.velocity[1] *= -node.elasticity;
                node.onGround = true;
            } else {
                node.onGround = false;
                node.velocity[1] += gravity;
            }
        }

        for (self.edges.items) |*edge| {
            if (self.clock % (if (edge.is_long) edge.long_time else edge.short_time) == 0) edge.is_long = !edge.is_long;

            const node1 = &self.nodes.items[edge.nodes[0]];
            const node2 = &self.nodes.items[edge.nodes[1]];

            var direction_vec = node2.pos - node1.pos;

            const length = @sqrt(@reduce(.Add, direction_vec * direction_vec));
            const target_length = if (edge.is_long) edge.long_length else edge.short_length;

            const force = edge.strength * (length - target_length);

            direction_vec *= @splat(1 / length * std.math.clamp(force, -2, 2));

            node1.velocity += direction_vec;
            node2.velocity -= direction_vec;
        }
    }

    pub fn getAvgPos(self: Creature) @Vector(2, f32) {
        var avg: @Vector(2, f32) = @splat(0);
        for (self.nodes.items) |n| {
            avg += n.pos;
        }

        avg /= @splat(@floatFromInt(self.nodes.items.len));
        return avg;
    }

    pub fn resetValues(self: *Creature, ground_level: f32, relax_graph_iters: usize) void {
        if (self.nodes.items.len == 0) return;
        c_prng.seed(self.seed);
        for (self.nodes.items) |*node| {
            node.velocity = @splat(0);
            node.pos[0] = c_random.float(f32);
            node.pos[1] = c_random.float(f32);
        }
        for (self.edges.items) |*edge| {
            edge.is_long = false;
        }
        self.clock = 0;
        self.fitness = 0;

        for (0..relax_graph_iters) |_| {
            self.tick(99999, 0, @splat(0.8));
        }

        self.clock = 0;

        var lowest_node = self.nodes.items[0];
        for (self.nodes.items[1..]) |node| {
            if (node.pos[1] > lowest_node.pos[1]) lowest_node = node;
        }

        const offset = ground_level - lowest_node.pos[1] - Node.radius;
        for (self.nodes.items) |*node| {
            node.pos[1] += offset;
        }
    }

    pub fn evaluate(self: *Creature, ticks: u16, gravity: f32, relax_graph_iters: usize, ground_level: f32, damping: @Vector(2, f32)) void {
        self.resetValues(gravity, relax_graph_iters);
        for (0..ticks) |_| {
            self.tick(ground_level, gravity, damping);
        }
        self.fitness = self.getAvgPos()[0];
    }

    pub fn crossover(self: Creature, other: Creature) !Creature {
        const node_amount = (self.nodes.items.len + other.nodes.items.len) / 2;
        var crossover_point = if (node_amount > 0) random.intRangeLessThan(usize, 0, node_amount) else 0;
        var nodes = try ArrayList(Node).initCapacity(self.nodes.allocator, node_amount);

        if (self.nodes.items.len < other.nodes.items.len) {
            if (self.nodes.items.len >= crossover_point) try nodes.appendSlice(self.nodes.items[0..crossover_point]) else crossover_point = 0;
            try nodes.appendSlice(other.nodes.items[crossover_point..node_amount]);
        } else {
            if (other.nodes.items.len >= crossover_point) try nodes.appendSlice(other.nodes.items[0..crossover_point]) else crossover_point = 0;
            try nodes.appendSlice(self.nodes.items[crossover_point..node_amount]);
        }

        const edges_amount = (self.edges.items.len + other.edges.items.len) / 2;
        crossover_point = if (edges_amount > 0) random.intRangeLessThan(usize, 0, edges_amount) else 0;
        var edges = try ArrayList(Muscle).initCapacity(self.edges.allocator, if (node_amount > 1) node_amount * (node_amount - 1) / 2 else 0);
        if (self.edges.items.len < other.edges.items.len) {
            if (self.edges.items.len >= crossover_point) try edges.appendSlice(self.edges.items[0..crossover_point]) else crossover_point = 0;
            try edges.appendSlice(other.edges.items[crossover_point..edges_amount]);
        } else {
            if (other.edges.items.len >= crossover_point) try edges.appendSlice(other.edges.items[0..crossover_point]) else crossover_point = 0;
            try edges.appendSlice(self.edges.items[crossover_point..edges_amount]);
        }

        // verify no edge points to a nonexisting node
        var i: usize = 0;
        while (i < edges.items.len) {
            for (edges.items[i].nodes) |n| {
                if (n >= nodes.items.len) {
                    _ = edges.swapRemove(i);
                    break;
                }
            } else i += 1;
        }

        return Creature{ .nodes = nodes, .edges = edges, .seed = random_values.seed() };
    }

    pub fn mutate(self: *Creature, ind_mut_chance: f16) !void {
        for (self.nodes.items) |*n| {
            if (random.float(f32) < ind_mut_chance) n.elasticity = random_values.elasticity();
            if (random.float(f32) < ind_mut_chance) n.friction = random_values.friction();
        }
        for (self.edges.items) |*e| {
            if (random.float(f32) < ind_mut_chance) e.long_length = random_values.long_length();
            if (random.float(f32) < ind_mut_chance) e.short_length = random_values.short_length();
            if (random.float(f32) < ind_mut_chance) e.strength = random_values.strength();
            if (random.float(f32) < ind_mut_chance) e.long_time = random_values.long_time();
            if (random.float(f32) < ind_mut_chance) e.short_time = random_values.short_time();
        }

        if (random.float(f32) < ind_mut_chance / 10) {
            if (random.boolean()) {
                // remove node
                if (self.nodes.items.len > 0) {
                    const node_idx = random.uintLessThan(usize, self.nodes.items.len);
                    _ = self.nodes.swapRemove(node_idx);
                    // verify no edge points to the removed node and repoint edges to the
                    // last node that was swapped.
                    var i: usize = 0;
                    while (i < self.edges.items.len) {
                        for (&self.edges.items[i].nodes) |*n| {
                            if (n.* == node_idx) {
                                _ = self.edges.swapRemove(i);
                                break;
                            } else if (n.* == self.nodes.items.len) {
                                n.* = node_idx;
                            }
                        } else i += 1;
                    }
                }
            } else {
                // add node
                try self.nodes.append(.{
                    .elasticity = random_values.elasticity(),
                    .friction = random_values.friction(),
                });
                if (self.nodes.items.len > 1) {
                    try self.edges.append(.{
                        .long_length = random_values.long_length(),
                        .short_length = random_values.short_length(),
                        .strength = random_values.strength(),
                        .long_time = random_values.long_time(),
                        .short_time = random_values.short_time(),
                        .nodes = .{
                            random.uintLessThan(usize, self.nodes.items.len - 1),
                            self.nodes.items.len - 1,
                        },
                    });
                }
            }
        }

        if (random.float(f32) < ind_mut_chance / 10) {
            if (random.boolean()) {
                // remove edge
                if (self.edges.items.len > 0) {
                    _ = self.edges.swapRemove(random.uintLessThan(usize, self.edges.items.len));
                }
            } else {
                // add edge
                if (self.nodes.items.len > 1) {
                    const a = random.uintLessThan(usize, self.nodes.items.len);
                    var b = random.uintLessThan(usize, self.nodes.items.len);
                    while (b == a) b = random.uintLessThan(usize, self.nodes.items.len);
                    try self.edges.append(.{
                        .long_length = random_values.long_length(),
                        .short_length = random_values.short_length(),
                        .strength = random_values.strength(),
                        .long_time = random_values.long_time(),
                        .short_time = random_values.short_time(),
                        .nodes = .{ a, b },
                    });
                }
            }
        }
    }

    pub fn createTest(node_amount: usize, ground_level: f32, allocator: std.mem.Allocator) !Creature {
        var nodes = try ArrayList(Node).initCapacity(allocator, node_amount);

        for (0..node_amount) |i| {
            try nodes.append(Node{
                .pos = .{
                    .x = @floatFromInt((i % 2) * 100),
                    .y = ground_level - 10 - 50 * @as(f32, @floatFromInt(i / 2)),
                },
                .elasticity = 0.5,
                .friction = 0.5,
            });
        }
        var edges = try ArrayList(Muscle).initCapacity(allocator, (node_amount * (node_amount - 1) / 2));

        for (0..nodes.items.len) |i| {
            for (i + 1..nodes.items.len) |j| {
                try edges.append(Muscle{
                    .nodes = .{ i, j },
                    .long_length = 200,
                    .short_length = 50,
                    .strength = 50,
                    .switch_at = 60 * 2,
                });
            }
        }

        return Creature{ .nodes = nodes, .edges = edges };
    }

    pub fn createRandom(node_amount: usize, connection_chance: f32, allocator: std.mem.Allocator) !Creature {
        var nodes = try ArrayList(Node).initCapacity(allocator, node_amount);

        for (0..node_amount) |_| {
            try nodes.append(Node{
                .elasticity = random_values.elasticity(),
                .friction = random_values.friction(),
            });
        }

        // initCapacity to maximum edges amount because even maximum edges is usually smaller then default size we get from normal init and append.
        var edges = try ArrayList(Muscle).initCapacity(allocator, (node_amount * (node_amount - 1) / 2));

        for (0..nodes.items.len) |i| {
            for (i + 1..nodes.items.len) |j| {
                if (random.float(f32) < connection_chance) {
                    const n1: f32 = random_values.long_length();
                    const n2: f32 = random_values.short_length();
                    try edges.append(Muscle{
                        .nodes = .{ i, j },
                        .long_length = @max(n1, n2),
                        .short_length = @min(n1, n2),
                        .strength = random_values.strength(),
                        .long_time = random_values.long_time(),
                        .short_time = random_values.short_time(),
                    });
                }
            }
        }
        return Creature{ .nodes = nodes, .edges = edges, .seed = random_values.seed() };
    }

    pub fn deinit(self: *Creature) void {
        self.edges.deinit();
        self.nodes.deinit();
    }

    pub fn clone(self: Creature) !Creature {
        var c = self;
        c.edges = try self.edges.clone();
        c.nodes = try self.nodes.clone();
        return c;
    }
};
