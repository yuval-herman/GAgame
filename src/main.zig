const r = @cImport({
    @cInclude("./raylib.h");
    @cInclude("./raymath.h");
});
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const screenWidth = 800;
const screenHeight = 450;
const groundLevel = screenHeight; // / 2;

var prng = std.Random.DefaultPrng.init(1);
const random = prng.random();

const gravity = 0; //.1;

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
        for (self.connections) |connection| {
            r.DrawLineEx(self.joints[connection[0]].pos, self.joints[connection[1]].pos, 5, r.BLACK);
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

    var connections = std.ArrayList([2]usize).init(allocator);
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
            if (connection[0] == current_joint and connection[1] == next_joint) {
                continue :graph_traversal;
            }
        }

        try connections.append(.{ current_joint, next_joint });
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

    var c = try makeRandomCreature(5, allocator);
    var i: usize = 0;
    while (!r.WindowShouldClose()) : (i += 1) // Detect window close button or ESC key
    {
        r.BeginDrawing();
        r.ClearBackground(r.RAYWHITE);

        c.deinit(allocator);
        c = try makeRandomCreature(random.intRangeAtMost(u8, 2, 7), allocator);

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
