const std = @import("std");
const logger = std.log.scoped(.Renderer);
const nvg = @import("nanovg");

const Vec2 = @import("Vec2.zig");
const DuelMatchState = @import("DuelMatchState.zig");

pub var vg: nvg = undefined;

var ball_image: nvg.Image = undefined;
var blobby_image: nvg.Image = undefined;
var background_image: nvg.Image = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    vg = try nvg.gl.init(allocator, .{});
}

pub fn load() void {
    _ = vg.createFontMem("fredoka", @embedFile("../fonts/FredokaOne-Regular.ttf"));
    ball_image = vg.createImageMem(@embedFile("../data/gfx/ball.png"), .{});
    blobby_image = vg.createImageMem(@embedFile("../data/gfx/blobby.png"), .{});
    background_image = vg.createImageMem(@embedFile("../data/backgrounds/strand2.bmp"), .{});
}

pub fn drawGame(game_state: DuelMatchState, draw_blobs: bool) void {
    // drawImageColor(background_image, 0, 0, nvg.rgbaf(1, 1, 1, 0.2));

    var pos = game_state.getBallPosition();
    if (false) {
        vg.save();
        defer vg.restore();
        vg.translate(pos.x, pos.y);
        vg.rotate(game_state.getBallRotation());
        drawImageColor(ball_image, -32, -32, nvg.rgbaf(1, 1, 1, 0.5));
    }

    if (draw_blobs) {
        pos = adjustBlobPosition(game_state.getBlobPosition(.left));
        drawImageColor(blobby_image, pos.x, pos.y, nvg.rgbf(1, 1, 0));

        pos = adjustBlobPosition(game_state.getBlobPosition(.right));
        drawImageColor(blobby_image, pos.x, pos.y, nvg.rgbf(0, 1, 1));
    }
}

fn adjustBlobPosition(pos: Vec2) Vec2 {
    return Vec2{ .x = pos.x - 37, .y = pos.y - 44 };
}

fn drawImage(image: nvg.Image, x: f32, y: f32) void {
    drawImageColor(image, x, y, nvg.rgbf(1, 1, 1));
}

fn drawImageColor(image: nvg.Image, x: f32, y: f32, color: nvg.Color) void {
    var iw: i32 = undefined;
    var ih: i32 = undefined;
    vg.imageSize(image, &iw, &ih);
    const w: f32 = @floatFromInt(iw);
    const h: f32 = @floatFromInt(ih);
    vg.beginPath();
    vg.rect(x, y, w, h);
    var paint = vg.imagePattern(x, y, w, h, 0, image, 1);
    paint.inner_color = color;
    paint.outer_color = color;
    vg.fillPaint(paint);
    vg.fill();
}

pub fn drawText(text: []const u8, x: f32, y: f32, alignment: nvg.TextAlign) void {
    vg.textAlign(alignment);
    vg.fontFace("fredoka");
    vg.fontSize(32.0);
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fontBlur(2);
    _ = vg.text(x, y + 1, text);
    vg.fontBlur(0);
    vg.fillColor(nvg.rgbf(1, 1, 1));
    _ = vg.text(x, y, text);
}

pub fn pointInText(
    point_x: f32,
    point_y: f32,
    text: []const u8,
    text_x: f32,
    text_y: f32,
    alignment: nvg.TextAlign,
) bool {
    vg.textAlign(alignment);
    vg.fontFace("fredoka");
    vg.fontSize(32.0);
    var bounds: [4]f32 = undefined;
    _ = vg.textBounds(text_x, text_y, text, &bounds);
    return point_x >= bounds[0] and point_y >= bounds[1] and point_x <= bounds[2] and point_y <= bounds[3];
}
