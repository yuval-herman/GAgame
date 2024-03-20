const r = @import("../../cHeaders.zig").raylib;

const Self = @This();

text: [*c]const u8,
x: c_int,
y: c_int,
font_size: c_int = 20,

pub fn draw(self: Self) void {
    r.DrawText(self.text, self.x, self.y, self.font_size, r.BLACK);
}
