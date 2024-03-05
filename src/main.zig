const r = @cImport({
    @cInclude("./raylib.h");
    @cInclude("./raymath.h");
});
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const screenWidth = 800;
const screenHeight = 450;
const groundLevel = screenHeight / 2;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

const gravity = 0.6;

const PhysicalCircle = struct {
    pos: r.Vector2 = r.Vector2{},
    force: r.Vector2 = r.Vector2{},
    radius: f16 = 10,
    ball_elasticity: f32 = -1,

    fn tick(self: *PhysicalCircle) void {
        self.force.x *= 0.1;
        self.force.y *= 0.1;
        if (self.pos.y + self.radius < groundLevel) {
            self.force.y += gravity;
        } else {
            if (self.force.y > 0) self.force.y *= self.ball_elasticity;
            std.debug.print("x:{d}\n", .{self.force.x});
            self.pos.y = groundLevel - self.radius;
        }

        self.pos = r.Vector2Add(self.pos, self.force);
    }
    fn draw(self: PhysicalCircle) void {
        r.DrawCircleV(self.pos, self.radius, r.RED);
    }
};

const JointConnection = struct {
    connected_joints: [2]usize,
    stretch_time: u8,
    is_stretching: bool = true,
    clock: u8 = 0,
};
const Creature = struct {
    joints: []PhysicalCircle,
    connections: []JointConnection,

    fn tick(self: *Creature) void {
        for (self.joints) |*joint| {
            joint.tick();
        }
        for (self.connections) |*connection| {
            connection.clock += 1;
            const max_time = connection.stretch_time;
            if (max_time == connection.clock) {
                connection.clock = 0;
                connection.is_stretching = !connection.is_stretching;
            }
            var joint_a = &self.joints[connection.connected_joints[0]];
            const joint_b = &self.joints[connection.connected_joints[1]];

            const dist = r.Vector2Distance(joint_a.pos, joint_b.pos);
            const multiplier: f16 = 10 * if (connection.is_stretching) @as(f16, -1) else @as(f16, 1);
            joint_a.force.y += (joint_b.pos.y - joint_a.pos.y) / dist * multiplier;
            joint_a.force.x += (joint_b.pos.x - joint_a.pos.x) / dist * multiplier;
        }
    }
    fn draw(self: Creature) void {
        for (self.connections) |connection| {
            r.DrawLineEx(
                self.joints[connection.connected_joints[0]].pos,
                self.joints[connection.connected_joints[1]].pos,
                if (connection.is_stretching) 5 else 10,
                r.BLACK,
            );
        }
        for (self.joints) |joint| {
            joint.draw();
        }
    }
    fn deinit(self: *Creature, allocator: Allocator) void {
        allocator.free(self.connections);
        allocator.free(self.joints);
    }
};

/// joint_amount must be bigger then 1.
fn makeRandomCreature(joint_amount: u8, allocator: Allocator) !Creature {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    assert(joint_amount > 1);
    const joints = try allocator.alloc(PhysicalCircle, joint_amount);
    for (joints) |*joint| {
        joint.* = PhysicalCircle{
            .pos = r.Vector2{
                .x = random.float(f32) * screenWidth / 2 + screenWidth / 4,
                .y = random.float(f32) * 300,
            },
            .ball_elasticity = -random.float(f32),
        };
    }

    var connections = std.ArrayList(JointConnection).init(allocator);
    defer connections.shrinkAndFree(connections.items.len);
    var joints_visits = try arena_allocator.alloc(bool, joint_amount);

    @memset(joints_visits, false);
    var current_joint: usize = 0;
    var next_joint: usize = 0;
    var unvisited_num = joint_amount;

    graph_traversal: while (unvisited_num > 0) {
        current_joint = random.uintLessThan(usize, joints_visits.len);

        if (!joints_visits[current_joint]) {
            joints_visits[current_joint] = true;
            unvisited_num -= 1;
        }

        while (next_joint == current_joint) {
            next_joint = random.uintLessThan(usize, joints_visits.len);
        }

        // If the two joints are already connected, skip
        for (connections.items) |connection| {
            if (connection.connected_joints[0] == current_joint and connection.connected_joints[1] == next_joint or
                connection.connected_joints[1] == current_joint and connection.connected_joints[0] == next_joint)
            {
                continue :graph_traversal;
            }
        }

        try connections.append(.{
            .connected_joints = .{ current_joint, next_joint },
            .stretch_time = random.uintAtMost(u8, 100),
        });
    }

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

    var c = try makeRandomCreature(2, allocator);
    defer c.deinit(allocator);
    var i: usize = 0;
    while (!r.WindowShouldClose()) : (i += 1) // Detect window close button or ESC key
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

const testing = std.testing;
test "creatue memory leak" {
    var buffer: [10000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var c: Creature = undefined;
    try testing.expectEqual(0, fba.end_index);

    c = try makeRandomCreature(2, allocator);

    c.deinit(allocator);

    try testing.expectEqual(0, fba.end_index);
}
