const std = @import("std");
const r = @import("cHeaders.zig").raylib;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

pub fn init(groundLevel: comptime_int, gravity: comptime_float) type {
    const Physics = @import("physics/particle.zig").init(groundLevel, gravity);
    const Particle = Physics.Particle;
    const Spring = Physics.ParticleSpring;
    return struct {
        pub const Creature = struct {
            joints: []Particle,
            connections: []Spring,

            pub fn tick(self: *Creature) void {
                for (self.joints) |*joint| {
                    joint.tick();
                }
                for (self.connections) |*connection| {
                    connection.tick();
                }
            }
            pub fn draw(self: Creature) void {
                for (self.connections) |connection| {
                    connection.draw();
                }
                for (self.joints) |joint| {
                    joint.draw();
                }
            }
            pub fn deinit(self: *Creature, allocator: Allocator) void {
                allocator.free(self.connections);
                allocator.free(self.joints);
            }
            pub fn getAvgPos(self: Creature) r.Vector2 {
                var avg = r.Vector2{};
                for (self.joints) |joint| {
                    avg.x += joint.pos.x;
                    avg.y += joint.pos.y;
                }
                avg.x /= @floatFromInt(self.joints.len);
                avg.y /= @floatFromInt(self.joints.len);
                return avg;
            }
        };

        /// joint_amount must be bigger then 1.
        pub fn makeRandomCreature(joint_amount: u8, allocator: Allocator) !Creature {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();
            assert(joint_amount > 1);
            const joints = try allocator.alloc(Particle, joint_amount);
            for (joints) |*joint| {
                joint.* = Particle{
                    .pos = r.Vector2{
                        .x = random.float(f32) * 600,
                        .y = random.float(f32) * 100,
                    },
                    .ball_elasticity = -random.float(f32),
                };
            }

            var connections = std.ArrayList([2]usize).init(allocator);
            defer connections.deinit();
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
                    if (connection[0] == current_joint and connection[1] == next_joint or
                        connection[1] == current_joint and connection[0] == next_joint)
                    {
                        continue :graph_traversal;
                    }
                }

                try connections.append(.{ current_joint, next_joint });
            }
            var springs = try allocator.alloc(Spring, connections.items.len);
            for (connections.items, 0..) |connection, i| {
                springs[i] = Spring{ .particals = .{ &joints[connection[0]], &joints[connection[1]] } };
            }
            return Creature{ .joints = joints, .connections = springs };
        }
    };
}
