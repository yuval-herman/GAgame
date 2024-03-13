const std = @import("std");
const r = @import("cHeaders.zig").raylib;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

const ArrayList = std.ArrayList;
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
pub fn init(GROUND_LEVEL: comptime_float, GRAVITY: comptime_float, DAMPING: comptime_float) type {
    return struct {
        const Creature = @This();
        nodes: ArrayList(Node),
        edges: ArrayList(Muscle),
        clock: u16 = 0,
        fitness: f32 = 0,

        pub fn tick(self: *Creature) void {
            self.clock +%= 1;
            for (self.nodes.items) |*node| {
                if (!node.isGrounded(GROUND_LEVEL)) {
                    node.velocity.y += GRAVITY;
                } else {
                    node.pos.y = GROUND_LEVEL - node.radius + 1; // can't be the exact ground position because of rounding errors
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

        pub fn getFarthestNodePos(self: Creature) r.Vector2 {
            var node = &self.nodes.items[0];
            for (self.nodes.items[1..]) |*n| {
                if (n.pos.x > node.pos.x) node = n;
            }
            return node.pos;
        }

        pub fn resetValues(self: *Creature) void {
            for (self.nodes.items, 0..) |*node, i| {
                node.pos.x = @floatFromInt(i * 10);
                node.pos.y = @floatFromInt(i * 10);
                node.velocity.x = 0;
                node.velocity.y = 0;
            }
            for (self.edges.items) |*edge| {
                edge.is_long = false;
            }
            self.clock = 0;
            self.fitness = 0;
        }

        pub fn evaluate(self: *Creature, ticks: u16) void {
            self.resetValues();
            for (0..ticks) |_| {
                self.tick();
            }
            self.fitness = self.getFarthestNodePos().x;
        }

        pub fn crossover(self: Creature, other: Creature) !Creature {
            const node_amount = @min(self.nodes.items.len, other.nodes.items.len);
            var crossover_point = random.intRangeLessThan(usize, 0, node_amount);
            var nodes = try ArrayList(Node).initCapacity(self.nodes.allocator, node_amount);
            if (self.nodes.items.len > other.nodes.items.len) {
                try nodes.appendSlice(self.nodes.items[0..crossover_point]);
                try nodes.appendSlice(other.nodes.items[crossover_point..]);
            } else {
                try nodes.appendSlice(other.nodes.items[0..crossover_point]);
                try nodes.appendSlice(self.nodes.items[crossover_point..]);
            }

            const edges_amount = @min(self.edges.items.len, other.edges.items.len);
            crossover_point = random.intRangeLessThan(usize, 0, edges_amount);
            var edges = try ArrayList(Muscle).initCapacity(self.edges.allocator, (node_amount * (node_amount - 1) / 2));
            if (self.edges.items.len < other.edges.items.len) {
                try edges.appendSlice(self.edges.items[0..crossover_point]);
                try edges.appendSlice(other.edges.items[crossover_point..]);
            } else {
                try edges.appendSlice(other.edges.items[0..crossover_point]);
                try edges.appendSlice(self.edges.items[crossover_point..]);
            }

            // verify no edge points to a nonexisting node
            var i: usize = 0;
            std.debug.print("before:{}\n", .{edges.items.len});
            while (i < edges.items.len) {
                for (edges.items[i].nodes) |n| {
                    std.debug.print("p:{} na:{}\n", .{ n, nodes.items.len });
                    if (n >= nodes.items.len) {
                        _ = edges.swapRemove(i);
                        std.debug.print("p:{} was removed\n", .{n});
                        break;
                    }
                } else i += 1;
            }
            std.debug.print("after:{}\n", .{edges.items.len});

            var c = Creature{ .nodes = nodes, .edges = edges };
            c.resetValues();
            return c;
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

            for (0..node_amount) |i| {
                try nodes.append(Node{
                    .pos = .{ .x = @floatFromInt(i), .y = @floatFromInt(i) },
                    .elasticity = random.float(f32),
                    .friction = random.float(f32),
                });
            }

            // initCapacity to maximum edges amount because even maximum edges is usually smaller then default size we get from normal init and append.
            var edges = try ArrayList(Muscle).initCapacity(allocator, (node_amount * (node_amount - 1) / 2));

            for (0..nodes.items.len) |i| {
                for (i + 1..nodes.items.len) |j| {
                    if (random.float(f32) < connection_chance) {
                        const n1: f32 = @floatFromInt(random.intRangeAtMost(u8, 10, 100));
                        const n2: f32 = @floatFromInt(random.intRangeAtMost(u8, 10, 100));
                        try edges.append(Muscle{
                            .nodes = .{ i, j },
                            .long_length = @max(n1, n2),
                            .short_length = @min(n1, n2),
                            .strength = random.float(f32) * 100,
                            .switch_at = random.intRangeAtMost(u8, 10, 255),
                        });
                    }
                }
            }

            return Creature{ .nodes = nodes, .edges = edges };
        }
    };
}
