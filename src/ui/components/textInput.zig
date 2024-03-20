const std = @import("std");
const r = @import("../../cHeaders.zig").raylib;

const Self = @This();

pos: r.Vector2,
textBuf: []u8,
font_size: c_int = 20,
color: r.Color = r.GRAY,
padding: f16 = 20,
has_focus: bool = false,
curr_idx: usize = 0,

pub fn draw(self: *Self) void {
    const marker_width = 20;
    const text_width: f32 = @floatFromInt(r.MeasureText(@ptrCast(self.textBuf), self.font_size));
    const rect = r.Rectangle{
        .x = self.pos.x,
        .y = self.pos.y,
        .width = @max(100, text_width + marker_width) + self.padding,
        .height = @as(f32, @floatFromInt(self.font_size)) + self.padding,
    };
    r.DrawRectangleRec(rect, self.color);
    const half_padding = self.padding / 2;
    r.DrawText(
        @ptrCast(self.textBuf),
        @intFromFloat(rect.x + half_padding),
        @intFromFloat(rect.y + half_padding),
        self.font_size,
        r.BLACK,
    );
    if (self.has_focus) {
        r.DrawRectangleRec(
            .{
                .x = rect.x + text_width + half_padding,
                .y = rect.y + rect.height - marker_width / 2,
                .width = marker_width,
                .height = marker_width / 2,
            },
            r.MAROON,
        );
    }

    if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
        if (r.CheckCollisionPointRec(r.GetMousePosition(), rect)) {
            self.has_focus = true;
        } else self.has_focus = false;
    }

    if (self.has_focus) {
        if (self.textBuf.len > self.curr_idx + 1) {
            const char: u8 = @intCast(r.GetCharPressed());
            if (char > 0) {
                self.textBuf[self.curr_idx] = char;
                self.curr_idx += 1;
            }
        }
        if (r.IsKeyPressed(r.KEY_BACKSPACE) and self.curr_idx > 0) {
            self.curr_idx -= 1;
            self.textBuf[self.curr_idx] = 0;
        }
    }
}

pub fn getText(self: Self) []u8 {
    return self.textBuf[0..self.curr_idx];
}
