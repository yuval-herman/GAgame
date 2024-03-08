const std = @import("std");
const r = @import("cHeaders.zig").raylib;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();
const MAX_JOINTS = 10;

pub fn init(groundLevel: comptime_int, gravity: comptime_float, allocator: Allocator) type {
    const Physics = @import("physics/particle.zig").init(groundLevel, gravity);
    const Particle = Physics.Particle;
    const Spring = Physics.ParticleSpring;
    return struct {
        pub const Creature = struct {
            joints: []Particle,
            connections: std.ArrayList(Spring),

            pub fn tick(self: *Creature) void {
                for (self.joints) |*joint| {
                    joint.tick();
                }
                for (self.connections.items) |*connection| {
                    connection.tick();
                }
            }
            pub fn draw(self: Creature) void {
                for (self.connections.items) |connection| {
                    connection.draw();
                }
                for (self.joints) |joint| {
                    joint.draw();
                }
            }
            pub fn deinit(self: *Creature) void {
                self.connections.deinit();
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

        /// 1 < joint_amount <= MAX_JOINTS.
        pub fn makeRandomCreature(joint_amount: u8) !Creature {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();
            assert(1 < joint_amount and joint_amount <= MAX_JOINTS);
            const joints = (try allocator.alloc(Particle, MAX_JOINTS))[0..joint_amount];
            for (joints) |*joint| {
                joint.* = Particle{
                    .pos = r.Vector2{
                        .x = random.float(f32) * 600,
                        .y = random.float(f32) * 100,
                    },
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
            var springs = try std.ArrayList(Spring).initCapacity(allocator, connections.items.len);
            for (connections.items) |connection| {
                try springs.append(Spring{ .particals = .{ &joints[connection[0]], &joints[connection[1]] } });
            }
            return Creature{ .joints = joints, .connections = springs };
        }

        pub fn mutateCreature(c: *Creature, ind_v_chance: f32) !void {
            if (random.float(f32) < ind_v_chance) {
                if (random.float(f32) < 0.5 and c.joints.len + 1 < MAX_JOINTS) {
                    const rnd_Joint_ptr = &c.joints[random.uintLessThan(usize, c.joints.len)];
                    c.joints.len += 1;
                    c.joints[c.joints.len - 1] = Particle{ .pos = .{ .x = 500 } };
                    try c.connections.append(Spring{
                        .particals = .{ rnd_Joint_ptr, &c.joints[c.joints.len - 1] },
                    });
                } else {
                    // TODO: remove joint
                }
            }
            if (random.float(f32) < ind_v_chance) {
                if (random.float(f32) < 0.5) {
                    const rnd_Joint_ptr1 = &c.joints[random.uintLessThan(usize, c.joints.len)];
                    var rnd_Joint_ptr2 = rnd_Joint_ptr1;
                    while (rnd_Joint_ptr2 == rnd_Joint_ptr1) {
                        rnd_Joint_ptr2 = &c.joints[random.uintLessThan(usize, c.joints.len)];
                    }
                    if (for (c.connections.items) |con| {
                        if ((con.particals[0] == rnd_Joint_ptr1 or con.particals[0] == rnd_Joint_ptr2) and
                            (con.particals[1] == rnd_Joint_ptr1 or con.particals[1] == rnd_Joint_ptr2))
                        {
                            break false;
                        }
                    } else true)
                        try c.connections.append(Spring{
                            .particals = .{ rnd_Joint_ptr1, rnd_Joint_ptr2 },
                        });
                } else if (c.connections.items.len > 0) {
                    _ = c.connections.swapRemove(random.uintLessThan(usize, c.connections.items.len));
                }
            }

            for (c.joints) |*joint| {
                if (random.float(f32) < ind_v_chance)
                    joint.slip_factor = @floatCast(random.float(f32));
            }
            for (c.connections.items) |*connection| {
                if (random.float(f32) < ind_v_chance)
                    connection.k = @rem(random.float(f32), 0.1);
                if (random.float(f32) < ind_v_chance)
                    connection.rest_length = random.intRangeAtMost(u16, 10, 150);
            }
        }
    };
}
