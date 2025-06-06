const r = @import("../../cHeaders.zig").raylib;

const Self = @This();

text: [*c]const u8,
action: *const fn () void,
pos: r.Vector2,
font_size: c_int = 20,
color: r.Color = r.LIGHTGRAY,
padding: f16 = 20,
cursor_set: bool = false,

pub fn draw(self: *Self) void {
    const rect = r.Rectangle{
        .x = self.pos.x,
        .y = self.pos.y,
        .width = @as(f32, @floatFromInt(r.MeasureText(self.text, self.font_size))) + self.padding,
        .height = @as(f32, @floatFromInt(self.font_size)) + self.padding,
    };
    r.DrawRectangleRec(rect, self.color);
    const half_padding = self.padding / 2;
    r.DrawText(
        self.text,
        @as(c_int, @intFromFloat(self.pos.x + half_padding)),
        @as(c_int, @intFromFloat(self.pos.y + half_padding)),
        self.font_size,
        r.BLACK,
    );

    if (r.CheckCollisionPointRec(r.GetMousePosition(), rect)) {
        r.SetMouseCursor(r.MOUSE_CURSOR_POINTING_HAND);
        self.cursor_set = true;
        if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
            self.action();
            self.cursor_set = false;
            r.SetMouseCursor(r.MOUSE_CURSOR_DEFAULT);
        }
    } else if (self.cursor_set) {
        self.cursor_set = false;
        r.SetMouseCursor(r.MOUSE_CURSOR_DEFAULT);
    }
}
