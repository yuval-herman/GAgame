const r = @import("cHeaders.zig").raylib;
const std = @import("std");

const SCREEN_WIDTH = 1000;
const SCREEN_HEIGHT = 500;
const GROUND_LEVEL = SCREEN_HEIGHT - 100;
const GRAVITY = 1;
const DMPING = 0.99;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

const ArrayList = std.ArrayList;
const Node = struct {
    pos: r.Vector2 = r.Vector2{},
    velocity: r.Vector2 = r.Vector2{},
    radius: f16 = 10,
    elasticity: f32 = 0.5,
    friction: f32 = 0.8,

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
const Creature = struct {
    nodes: ArrayList(Node),
    edges: ArrayList(Muscle),
    clock: u16 = 0,

    pub fn tick(self: *Creature) void {
        self.clock +%= 1;
        for (self.nodes.items) |*node| {
            if (!node.isGrounded(GROUND_LEVEL)) {
                node.velocity.y += GRAVITY;
            } else {
                node.pos.y = GROUND_LEVEL - node.radius + 1; // can't be the exact ground position because of rounding errors
                // node.velocity.x *= -node.friction;
                node.velocity.y *= -node.elasticity;
            }
            node.pos.x += node.velocity.x;
            node.pos.y += node.velocity.y;
            node.velocity.x *= DMPING;
            node.velocity.y *= DMPING;
        }

        for (self.edges.items) |*edge| {
            if (self.clock % edge.switch_at == 0) edge.is_long = !edge.is_long;

            const node1 = &self.nodes.items[edge.nodes[0]];
            const node2 = &self.nodes.items[edge.nodes[1]];

            var direction_vec = r.Vector2Subtract(node2.pos, node1.pos);
            const length = r.Vector2Length(direction_vec);
            direction_vec.x = 1 / length;
            direction_vec.y = 1 / length;

            const force = edge.strength * (length - (if (edge.is_long) edge.long_length else edge.short_length));
            direction_vec.x *= force;
            direction_vec.y *= force;

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

    pub fn createRandom(node_amount: usize, connection_chance: f32, allocator: std.mem.Allocator) !Creature {
        var nodes = try ArrayList(Node).initCapacity(allocator, node_amount);

        for (0..node_amount) |i| {
            try nodes.append(.{ .pos = .{ .x = @floatFromInt(i), .y = @floatFromInt(i) } });
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
                        .strength = 0.002, //random.float(f32) / 10,
                        .switch_at = random.intRangeAtMost(u8, 10, 255),
                    });
                }
            }
        }

        return Creature{ .nodes = nodes, .edges = edges };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
    const allocator = gpa.allocator();
    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "my window! WOOOOOOOOOOOW!!!!!!");
    defer r.CloseWindow();
    r.SetTargetFPS(60);

    const camera = r.Camera2D{
        .zoom = 1,
        // .offset = .{ .x = screenWidth / 2, .y = SCREEN_HEIGHT / 2 },
    };

    var c = try Creature.createRandom(4, 0.5, allocator);
    for (c.nodes.items) |*node| {
        node.pos.x += 400;
    }

    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);
        r.BeginMode2D(camera);
        c.tick();
        c.draw();
        r.DrawRectangle(0, GROUND_LEVEL, SCREEN_WIDTH, 500, r.BLACK);
        r.EndMode2D();
        r.EndDrawing();
    }
}
