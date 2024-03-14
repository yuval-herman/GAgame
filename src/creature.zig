const std = @import("std");
const r = @import("cHeaders.zig").raylib;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

const ArrayList = std.ArrayList;

const random_values = struct {
    fn elasticity() f32 {
        return random.float(f32) / 10;
    }
    fn friction() f32 {
        return random.float(f32);
    }
    fn strength() f32 {
        return random.float(f32) * 100;
    }
    fn long_length() f32 {
        return random.float(f32) * (100 - 10) + 10;
    }
    fn short_length() f32 {
        return long_length();
    }
    fn switch_at() u8 {
        return random.intRangeAtMost(u8, 10, 255);
    }
};

const Node = struct {
    pos: r.Vector2 = r.Vector2{},
    velocity: r.Vector2 = r.Vector2{},
    radius: f16 = 10,
    elasticity: f32,
    friction: f32,

    pub fn isGrounded(self: Node, ground_level: f32) bool {
        return self.pos.y + self.radius >= ground_level;
    }
};
const Muscle = struct {
    nodes: [2]usize,
    strength: f32,
    long_length: f32,
    short_length: f32,
    switch_at: u8,
    is_long: bool = false,
};
pub fn init(GROUND_LEVEL: comptime_float, GRAVITY: comptime_float, DAMPING: comptime_float, RELAX_GRAPH_ITERS: comptime_int) type {
    return struct {
        const Creature = @This();
        nodes: ArrayList(Node),
        edges: ArrayList(Muscle),
        clock: u16 = 0,
        fitness: f32 = 0,

        pub fn tick(self: *Creature) void {
            tick_values(self, GROUND_LEVEL, GRAVITY);
        }
        pub fn tick_values(self: *Creature, ground_level: comptime_float, gravity: comptime_float) void {
            self.clock +%= 1;
            for (self.nodes.items) |*node| {
                if (!node.isGrounded(ground_level)) {
                    node.velocity.y += gravity;
                } else {
                    node.pos.y = ground_level - node.radius + 1; // can't be the exact ground position because of rounding errors
                    node.velocity.x *= node.friction;
                    node.velocity.y *= -node.elasticity;
                }
                node.pos.x += node.velocity.x;
                node.pos.y += node.velocity.y;
                node.velocity.x *= DAMPING;
                node.velocity.y *= DAMPING;
            }

            for (self.edges.items) |*edge| {
                if (self.clock % edge.switch_at == 0) edge.is_long = !edge.is_long;

                const node1 = &self.nodes.items[edge.nodes[0]];
                const node2 = &self.nodes.items[edge.nodes[1]];

                var direction_vec = r.Vector2Subtract(node2.pos, node1.pos);
                const length = r.Vector2Length(direction_vec);

                const force = edge.strength * std.math.tanh((length - if (edge.is_long) edge.long_length else edge.short_length) / 1000);

                direction_vec.x *= 1 / length * force;
                direction_vec.y *= 1 / length * force;

                node1.velocity.x += direction_vec.x;
                node1.velocity.y += direction_vec.y;
                node2.velocity.x -= direction_vec.x;
                node2.velocity.y -= direction_vec.y;
            }
        }

        pub fn draw(self: Creature) void {
            for (self.edges.items) |edge| {
                r.DrawLineEx(
                    self.nodes.items[edge.nodes[0]].pos,
                    self.nodes.items[edge.nodes[1]].pos,
                    if (edge.is_long) 15 else 10,
                    r.BLACK,
                );
            }
            for (self.nodes.items) |node| {
                r.DrawCircleV(node.pos, node.radius, r.RED);
            }
        }

        pub fn getAvgPos(self: Creature) r.Vector2 {
            var avg = r.Vector2{};
            for (self.nodes.items) |n| {
                avg.x += n.pos.x;
                avg.y += n.pos.y;
            }
            avg.x /= @floatFromInt(self.nodes.items.len);
            avg.y /= @floatFromInt(self.nodes.items.len);
            return avg;
        }

        pub fn resetValues(self: *Creature) void {
            for (self.nodes.items) |*node| {
                node.velocity.x = 0;
                node.velocity.y = 0;
            }
            for (self.edges.items) |*edge| {
                edge.is_long = false;
            }
            self.clock = 0;
            self.fitness = 0;

            for (self.nodes.items) |*node| {
                node.pos.x = random.float(f32);
                node.pos.y = random.float(f32);
            }
            for (0..RELAX_GRAPH_ITERS) |_| {
                self.tick_values(99999, 0);
            }
        }

        pub fn evaluate(self: *Creature, ticks: u16) void {
            self.resetValues();
            for (0..ticks) |_| {
                self.tick();
            }
            self.fitness = self.getAvgPos().x;
        }

        pub fn crossover(self: Creature, other: Creature) !Creature {
            const node_amount = @min(self.nodes.items.len, other.nodes.items.len);
            var crossover_point = if (node_amount > 0) random.intRangeLessThan(usize, 0, node_amount) else 0;
            var nodes = try ArrayList(Node).initCapacity(self.nodes.allocator, node_amount);

            if (self.nodes.items.len > other.nodes.items.len) {
                try nodes.appendSlice(self.nodes.items[0..crossover_point]);
                try nodes.appendSlice(other.nodes.items[crossover_point..]);
            } else {
                try nodes.appendSlice(other.nodes.items[0..crossover_point]);
                try nodes.appendSlice(self.nodes.items[crossover_point..]);
            }

            const edges_amount = @min(self.edges.items.len, other.edges.items.len);
            crossover_point = if (edges_amount > 0) random.intRangeLessThan(usize, 0, edges_amount) else 0;
            var edges = try ArrayList(Muscle).initCapacity(self.edges.allocator, if (node_amount > 1) node_amount * (node_amount - 1) / 2 else 0);
            if (self.edges.items.len < other.edges.items.len) {
                try edges.appendSlice(self.edges.items[0..crossover_point]);
                try edges.appendSlice(other.edges.items[crossover_point..]);
            } else {
                try edges.appendSlice(other.edges.items[0..crossover_point]);
                try edges.appendSlice(self.edges.items[crossover_point..]);
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

            var c = Creature{ .nodes = nodes, .edges = edges };
            c.resetValues();
            return c;
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
                if (random.float(f32) < ind_mut_chance) e.switch_at = random_values.switch_at();
            }

            // add or remove node
            if (random.float(f32) < ind_mut_chance) {
                if (random.boolean()) {
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
                    try self.nodes.append(.{
                        .elasticity = random_values.elasticity(),
                        .friction = random_values.friction(),
                    });
                    if (self.nodes.items.len > 1) {
                        try self.edges.append(.{
                            .long_length = random_values.long_length(),
                            .short_length = random_values.short_length(),
                            .strength = random_values.strength(),
                            .switch_at = random_values.switch_at(),
                            .nodes = .{
                                random.uintLessThan(usize, self.nodes.items.len - 1),
                                self.nodes.items.len - 1,
                            },
                        });
                    }
                }
            }
            // add or remove edge
            if (random.float(f32) < ind_mut_chance) {
                if (random.boolean()) {
                    if (self.edges.items.len > 0) {
                        _ = self.edges.swapRemove(random.uintLessThan(usize, self.edges.items.len));
                    }
                } else {
                    if (self.nodes.items.len > 1) {
                        const a = random.uintLessThan(usize, self.nodes.items.len);
                        var b = random.uintLessThan(usize, self.nodes.items.len);
                        while (b == a) b = random.uintLessThan(usize, self.nodes.items.len);
                        try self.edges.append(.{
                            .long_length = random_values.long_length(),
                            .short_length = random_values.short_length(),
                            .strength = random_values.strength(),
                            .switch_at = random_values.switch_at(),
                            .nodes = .{ a, b },
                        });
                    }
                }
            }
        }

        pub fn createTest(node_amount: usize, allocator: std.mem.Allocator) !Creature {
            var nodes = try ArrayList(Node).initCapacity(allocator, node_amount);

            for (0..node_amount) |i| {
                try nodes.append(Node{
                    .pos = .{
                        .x = @floatFromInt((i % 2) * 100),
                        .y = GROUND_LEVEL - 10 - 50 * @as(f32, @floatFromInt(i / 2)),
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
                            .switch_at = random_values.switch_at(),
                        });
                    }
                }
            }
            var c = Creature{ .nodes = nodes, .edges = edges };
            c.resetValues();
            return c;
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
}
