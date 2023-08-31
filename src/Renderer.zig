const std = @import("std");
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

pub fn drawGame(game_state: DuelMatchState) void {
    drawImageColor(background_image, 0, 0, nvg.rgbaf(1, 1, 1, 0.2));

    var pos = game_state.getBallPosition();
    {
        vg.save();
        defer vg.restore();
        vg.translate(pos.x, pos.y);
        vg.rotate(game_state.getBallRotation());
        drawImage(ball_image, -32, -32);
    }

    pos = adjustBlobPosition(game_state.getBlobPosition(.left));
    drawImageColor(blobby_image, pos.x, pos.y, nvg.rgbf(1, 1, 0));

    pos = adjustBlobPosition(game_state.getBlobPosition(.right));
    drawImageColor(blobby_image, pos.x, pos.y, nvg.rgbf(0, 1, 1));
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

pub fn drawText(text: []const u8, x: f32, y: f32) void {
    vg.fontFace("fredoka");
    vg.fontSize(32.0);
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fontBlur(2);
    _ = vg.text(x, y + 1, text);
    vg.fontBlur(0);
    vg.fillColor(nvg.rgbf(1, 1, 1));
    _ = vg.text(x, y, text);
}
