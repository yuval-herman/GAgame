const std = @import("std");
const utils = @import("utils.zig");

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

var c_prng = std.Random.DefaultPrng.init(0);
const c_random = c_prng.random();

const ArrayList = std.ArrayList;

pub const max_strength = 2;

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
        return random.float(f32) * max_strength;
    }
    fn long_length() f32 {
        return random.float(f32) * 200 + 10;
    }
    fn short_length() f32 {
        return long_length();
    }
    fn bias() f32 {
        return random.float(f32);
    }
    fn weight() @Vector(2, f32) {
        return .{ random.float(f32), random.float(f32) };
    }
    fn weights(weights_slice: []@Vector(2, f32)) void {
        for (weights_slice) |*w| w.* = weight();
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
    bias: f32,
    weights: std.ArrayList(@Vector(2, f32)),
    fn think(self: Muscle, nodes: []const Node, avg_pos: @Vector(2, f32)) bool {
        if (self.weights.items.len == 0) return false;
        var sum: f32 = 0;
        for (nodes, 0..) |node, i| {
            const v = (node.pos - avg_pos) * self.weights.items[i];
            sum += v[0];
            sum += v[1];
        }
        sum += self.bias;
        return sum <= 0;
    }
};

pub const Creature = struct {
    nodes: ArrayList(Node),
    edges: ArrayList(Muscle),
    fitness: f64 = 0,
    seed: u64,

    pub fn tick(self: *Creature, ground_level: f32, gravity: f32, damping: @Vector(2, f32)) void {
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

        const avg_pos = self.getAvgPos();
        for (self.edges.items) |*edge| {
            const node1 = &self.nodes.items[edge.nodes[0]];
            const node2 = &self.nodes.items[edge.nodes[1]];

            var direction_vec = node2.pos - node1.pos;

            const length = @sqrt(@reduce(.Add, direction_vec * direction_vec));
            const target_length = if (edge.think(self.nodes.items, avg_pos)) edge.long_length else edge.short_length;

            const force = edge.strength * (length - target_length);

            direction_vec *= @splat(1 / length * std.math.clamp(force, -max_strength, max_strength));

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

        self.fitness = 0;

        for (0..relax_graph_iters) |_| {
            self.tick(99999, 0, @splat(0.8));
        }

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
        self.resetValues(ground_level, relax_graph_iters);
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

        // we `weights.clone` because edges themselves are being compied in `edges.appendSlice` but inner pointers
        // such as the weights do not get copied.
        for (edges.items) |*e| {
            e.weights = try e.weights.clone();
        }

        // verify no edge points to a nonexisting node
        var i: usize = 0;
        while (i < edges.items.len) {
            const diff = @as(i64, @intCast(nodes.items.len)) - @as(i64, @intCast(edges.items[i].weights.items.len));
            if (diff >= 1) {
                for (try edges.items[i].weights.addManyAsSlice(@intCast(diff))) |*w| w.* = random_values.weight();
            } else if (diff < 1) {
                try edges.items[i].weights.resize(nodes.items.len);
            }

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
            for (e.weights.items) |*w| {
                if (random.float(f32) < ind_mut_chance / 10) w.* = random_values.weight();
            }
        }

        if (random.float(f32) < ind_mut_chance / 10) {
            if (random.boolean()) {
                // remove node
                if (self.nodes.items.len > 0) {
                    const node_idx = random.uintLessThan(usize, self.nodes.items.len);
                    // truncate the weights array.
                    // TODO investigate if worth to remove specifically to weight associated with the removed node.
                    _ = self.nodes.swapRemove(node_idx);

                    // verify no edge points to the removed node and repoint edges to the
                    // last node that was swapped.
                    var i: usize = 0;
                    _ = self.edges.items[i].weights.pop();
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
                for (self.edges.items) |*e| {
                    try e.weights.append(random_values.weight());
                }
                if (self.nodes.items.len > 1) {
                    try self.edges.append(try makeEdge(
                        random.uintLessThan(usize, self.nodes.items.len - 1),
                        self.nodes.items.len - 1,
                        self.nodes.items.len,
                        self.edges.allocator,
                    ));
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
                    try self.edges.append(try makeEdge(a, b, self.nodes.items.len, self.edges.allocator));
                }
            }
        }
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
                    try edges.append(try makeEdge(i, j, nodes.items.len, allocator));
                }
            }
        }
        return Creature{ .nodes = nodes, .edges = edges, .seed = random_values.seed() };
    }

    pub fn deinit(self: *Creature) void {
        for (self.edges.items) |*e| {
            e.weights.deinit();
        }
        self.edges.deinit();
        self.nodes.deinit();
    }

    pub fn clone(self: Creature) !Creature {
        var c = self;
        c.edges = try self.edges.clone();
        for (c.edges.items, self.edges.items) |*c_edge, *e| {
            c_edge.weights = try e.weights.clone();
        }
        c.nodes = try self.nodes.clone();
        return c;
    }
};

fn makeEdge(n1: usize, n2: usize, node_amount: usize, allocator: std.mem.Allocator) !Muscle {
    var weights = try std.ArrayList(@Vector(2, f32)).initCapacity(allocator, node_amount);
    weights.appendNTimesAssumeCapacity(@splat(0), node_amount);
    random_values.weights(weights.items);
    return Muscle{
        .weights = weights,
        .bias = random_values.bias(),
        .nodes = .{ n1, n2 },
        .long_length = random_values.long_length(),
        .short_length = random_values.short_length(),
        .strength = random_values.strength(),
    };
}
