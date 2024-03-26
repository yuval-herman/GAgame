const std = @import("std");
const CreaturePackage = @import("../../creature.zig");
const Creature = CreaturePackage.Creature;
const max_strength = CreaturePackage.max_strength;
const Node = CreaturePackage.Node;
const r = @import("../../cHeaders.zig").raylib;
const utils = @import("../../utils.zig");
const G = @import("../../global_state.zig");

const bufPrint = std.fmt.bufPrint;

var textBuffer: [10000]u8 = undefined;

fn creatureDraw(c: Creature) void {
    for (c.edges.items) |edge| {
        const min_line_strength = 0.1;
        r.DrawLineEx(
            utils.v2FromVector(c.nodes.items[edge.nodes[0]].pos),
            utils.v2FromVector(c.nodes.items[edge.nodes[1]].pos),
            10, //if (edge.is_long) 20 else
            r.ColorAlpha(r.BLACK, (1 - min_line_strength) * edge.strength / max_strength + min_line_strength),
        );
    }
    for (c.nodes.items) |node| {
        r.DrawCircleV(utils.v2FromVector(node.pos), Node.radius, r.ColorBrightness(r.WHITE, node.friction * 2 - 1));
        r.DrawCircleLinesV(utils.v2FromVector(node.pos), Node.radius, r.BLACK);
    }
}

var camera = r.Camera2D{
    .zoom = 1,
    .offset = .{ .x = 1000 / 2, .y = 500 / 2 },
};
var current_c: Creature = undefined;
var generation: usize = 0;
var changeC = true;
var show_all = false;

pub fn draw() !void {
    if (r.IsKeyPressed(r.KEY_S)) {
        if (!show_all) {
            for (G.app_state.best_history.items) |*crit| {
                crit.resetValues(G.app_state.GROUND_LEVEL, G.RELAX_GRAPH_ITERS);
            }
        }
        show_all = !show_all;
    }
    if (r.IsKeyPressed(r.KEY_ENTER)) {
        std.debug.print("\n\n", .{});
        for (current_c.edges.items, 0..) |e, i| {
            std.debug.print("edge {}: {d}\n\n", .{ i, e.weights.items });
        }
        std.debug.print("\n\n", .{});
    }
    if (r.IsKeyDown(r.KEY_RIGHT) and generation < G.app_state.best_history.items.len - 1) {
        generation += 1;
        changeC = true;
    }
    if (r.IsKeyDown(r.KEY_LEFT) and generation >= 1) {
        generation -= 1;
        changeC = true;
    }
    if (r.IsKeyDown(r.KEY_DOWN) and G.app_state.fps > 1) {
        G.app_state.fps -= 1;
        r.SetTargetFPS(G.app_state.fps);
    }
    if (r.IsKeyDown(r.KEY_UP) and G.app_state.fps < std.math.maxInt(c_int)) {
        G.app_state.fps += 1;
        r.SetTargetFPS(G.app_state.fps);
    }
    if (r.IsKeyDown(r.KEY_END)) {
        generation = G.app_state.best_history.items.len - 1;
        changeC = true;
    }
    if (r.IsKeyDown(r.KEY_HOME)) {
        generation = 0;
        changeC = true;
    }
    if (changeC) {
        changeC = false;
        current_c = G.app_state.best_history.items[generation];
        if (!show_all) {
            const avg = current_c.getAvgPos();
            std.debug.print("cI: {} avg: ({d:.2}, {d:.2})\n", .{ generation, avg[0], avg[1] });
            current_c.resetValues(G.app_state.GROUND_LEVEL, G.RELAX_GRAPH_ITERS);
        }
    }
    r.BeginMode2D(camera);

    var text_buffer_idx: usize = 0;
    var text_slice: []u8 = undefined;
    for (0..200) |i| {
        const font_size = 30;
        var sign = r.Rectangle{
            .x = @floatFromInt(i * 250),
            .y = G.app_state.GROUND_LEVEL - 150,
            .height = 50,
            .width = undefined,
        };
        text_slice = try bufPrint(textBuffer[text_buffer_idx..], "{d:.1}", .{sign.x / 100});
        text_buffer_idx += text_slice.len + 1; // add one to account for c-style null termination.
        const text: [*c]u8 = @ptrCast(text_slice);
        const text_width: f32 = @floatFromInt(r.MeasureText(text, font_size));
        sign.width = @max(100, text_width + 20);
        r.DrawRectangleRec(sign, r.LIGHTGRAY);
        r.DrawText(
            text,
            @intFromFloat(sign.x + sign.width / 2 - text_width / 2),
            @intFromFloat(sign.y + sign.height / 2 - font_size / 2),
            font_size,
            r.BLACK,
        );
    }

    if (show_all) {
        for (G.app_state.best_history.items) |*crit| {
            crit.tick(G.app_state.GROUND_LEVEL, G.app_state.GRAVITY, G.app_state.DAMPING);
            creatureDraw(crit.*);
        }
    } else {
        current_c.tick(G.app_state.GROUND_LEVEL, G.app_state.GRAVITY, G.app_state.DAMPING);
        creatureDraw(current_c);
    }

    var center_pos: @Vector(2, f32) = @splat(0);
    var farthest_pos: @Vector(2, f32) = current_c.nodes.items[0].pos;
    for (current_c.nodes.items) |n| {
        center_pos += n.pos;
        if (n.pos[0] < farthest_pos[0]) farthest_pos = n.pos;
    }
    center_pos /= @splat(@floatFromInt(current_c.nodes.items.len));
    camera.target.x = center_pos[0];
    camera.target.y = center_pos[1];
    camera.zoom = @min(1, @as(f32, @floatFromInt(G.app_state.SCREEN_WIDTH)) / ((center_pos[0] - farthest_pos[0]) * 2));

    text_slice = try bufPrint(textBuffer[text_buffer_idx..], "{d:.1}", .{camera.target.x});
    text_buffer_idx += text_slice.len + 1; // add one to account for c-style null termination.

    r.DrawText(
        @ptrCast(text_slice),
        @intFromFloat(camera.target.x),
        @intFromFloat(camera.target.y - 200),
        20,
        r.BLACK,
    );

    r.DrawRectangle(@as(c_int, @intFromFloat(camera.target.x)) - G.app_state.SCREEN_WIDTH, @intFromFloat(G.app_state.GROUND_LEVEL), G.app_state.SCREEN_WIDTH * 2, 500, r.BLACK);

    r.EndMode2D();
    text_slice = try bufPrint(textBuffer[text_buffer_idx..], "fps {d:.2}", .{1 / r.GetFrameTime()});
    text_buffer_idx += text_slice.len + 1; // add one to account for c-style null termination.

    r.DrawText(
        @ptrCast(text_slice),
        0,
        50,
        20,
        r.BLACK,
    );
    text_slice = try bufPrint(textBuffer[text_buffer_idx..], "generation {d}", .{generation});
    text_buffer_idx += text_slice.len + 1; // add one to account for c-style null termination.

    r.DrawText(
        @ptrCast(text_slice),
        0,
        100,
        20,
        r.BLACK,
    );
    @memset(textBuffer[0..text_buffer_idx], 0);
}
