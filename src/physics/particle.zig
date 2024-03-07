const r = @import("../cHeaders.zig").raylib;

pub fn initParticleStruct(groundLevel: comptime_int, gravity: comptime_float) type {
    return struct {
        const Self = @This();
        radius: f16 = 10,
        pos: r.Vector2 = r.Vector2{},
        velocity: r.Vector2 = r.Vector2{},
        ball_elasticity: f32 = -1,
        is_touching_ground: bool = false,
        slip_factor: f16 = 0.05,

        pub fn tick(self: *Self) void {
            // damping
            self.velocity.y *= 0.99;

            if (self.pos.y + self.radius + 1 >= groundLevel) {
                self.pos.y = groundLevel - self.radius;
                self.velocity.y *= -0.8;
                self.velocity.x *= self.slip_factor;
            } else {
                self.velocity.y += gravity;
            }

            self.pos.x += self.velocity.x;
            self.pos.y += self.velocity.y;
        }
        pub fn draw(self: Self) void {
            r.DrawCircleV(self.pos, self.radius, r.RED);
        }
    };
}

pub fn initParticleSpring(groundLevel: comptime_int, gravity: comptime_float) type {
    return struct {
        const Self = @This();
        particals: [2]*initParticleStruct(groundLevel, gravity),
        k: f32 = 0.01,
        rest_length: u16 = 100,

        pub fn tick(self: *Self) void {
            self.particals[0].tick();
            self.particals[1].tick();
            var F = r.Vector2Subtract(self.particals[1].pos, self.particals[0].pos);
            const mag = r.Vector2Length(F) - @as(f32, @floatFromInt(self.rest_length));
            F = r.Vector2Scale(r.Vector2Normalize(F), self.k * mag);
            self.particals[0].velocity.y += F.y;
            self.particals[0].velocity.x += F.x;
            self.particals[1].velocity.y -= F.y;
            self.particals[1].velocity.x -= F.x;
        }
        pub fn draw(self: Self) void {
            r.DrawLineEx(self.particals[0].pos, self.particals[1].pos, 3, r.BLACK);
            self.particals[0].draw();
            self.particals[1].draw();
        }
    };
}
