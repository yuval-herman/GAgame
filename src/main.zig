const r = @cImport({
    @cInclude("./raylib.h");
    @cInclude("./raymath.h");
});
const std = @import("std");

const screenWidth = 800;
const screenHeight = 450;
const groundLevel = screenHeight / 2;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

const gravity = 0.1;

const PhysicalCircle = struct {
    pos: r.Vector2 = r.Vector2{},
    velocity: r.Vector2 = r.Vector2{},
    radius: f16 = 10,
    ball_elasticity: f32 = -0.3,

    fn tick(self: *PhysicalCircle) void {
        if (self.pos.y + self.radius < groundLevel) {
            self.velocity.y += gravity;
        } else {
            self.velocity.y *= self.ball_elasticity;
            self.pos.y = groundLevel - self.radius;
        }
        self.pos = r.Vector2Add(self.pos, self.velocity);
    }
    fn draw(self: PhysicalCircle) void {
        r.DrawCircleV(self.pos, self.radius, r.RED);
    }
};

const Creature = struct {
    joints: []PhysicalCircle,
    connections: [][2]usize,

    fn tick(self: *Creature) void {
        for (self.joints) |*joint| {
            joint.tick();
        }
    }
    fn draw(self: Creature) void {
        for (self.joints) |joint| {
            joint.draw();
        }
        for (self.connections) |connection| {
            r.DrawLineEx(self.joints[connection[0]].pos, self.joints[connection[1]].pos, 5, r.BLACK);
        }
    }
};

fn makeRandomCreature(joint_amount: u8, allocator: std.mem.Allocator) !Creature {
    const joints = try allocator.alloc(PhysicalCircle, joint_amount);
    for (joints) |*joint| {
        joint.* = PhysicalCircle{
            .pos = .{
                .x = random.float(f32) * screenWidth / 2 + screenWidth / 4,
                .y = random.float(f32) * 300,
            },
            .ball_elasticity = -random.float(f32),
        };
    }
    var connections = std.ArrayList([2]usize).init(allocator);
    var joints_visits = try allocator.alloc(bool, joint_amount);

    @memset(joints_visits, false);
    var current_joint: usize = 0;
    var next_cell: usize = 0;
    var unvisited_num = joint_amount;

    graph_traversal: while (unvisited_num > 0) {
        current_joint = random.uintLessThan(usize, joints_visits.len);

        std.debug.print("stage: loop_begin current_joint: {} next_cell: {} unvisited_num: {}\n", .{
            current_joint,
            next_cell,
            unvisited_num,
        });

        if (!joints_visits[current_joint]) {
            joints_visits[current_joint] = true;
            unvisited_num -= 1;
        } // mark joint as visited
        while (joints_visits[next_cell]) {
            if (unvisited_num == 0) break;
            next_cell = random.uintLessThan(usize, joints_visits.len);
            std.debug.print("stage: inner_next_cell_loop current_joint: {} next_cell: {} unvisited_num: {}\n", .{
                current_joint,
                next_cell,
                unvisited_num,
            });
        }
        for (connections.items) |connection| {
            if (connection[0] == current_joint and connection[1] == next_cell) continue :graph_traversal;
        }
        var connection = try allocator.create([2]usize);
        connection[0] = current_joint;
        connection[1] = next_cell;
        try connections.append(connection.*);
    }

    // actions:
    // 1. mark current cell visited.
    // 2. aquire list of unvisited cells.
    // 3. choose random next cell, or travel along connection.
    // 4. if choosing random cell, connect the cells.

    return Creature{ .joints = joints, .connections = connections.items };
}

pub fn main() !void {
    var buffer: [10000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    r.SetConfigFlags(r.FLAG_MSAA_4X_HINT);
    r.InitWindow(screenWidth, screenHeight, "raylib [core] example - basic window");
    defer r.CloseWindow();
    r.SetTargetFPS(60);

    var c = try makeRandomCreature(5, allocator);
    while (!r.WindowShouldClose()) // Detect window close button or ESC key
    {
        r.BeginDrawing();

        r.ClearBackground(r.RAYWHITE);

        c.tick();
        c.draw();
        // r.DrawText(@ptrCast(try std.fmt.bufPrintZ(&buffer, "{any}", .{c})), 0, 0, 20, r.LIGHTGRAY);

        // Draw ground
        r.DrawRectangle(0, groundLevel, screenWidth, screenHeight, r.BLACK);

        r.EndDrawing();
    }
}
