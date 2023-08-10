const std = @import("std");

const nvg = @import("nanovg");

const wasm = @import("web/wasm.zig");
pub const std_options = struct {
    pub const log_level = .info;
    pub const logFn = wasm.log;
};
const gl = @import("web/webgl.zig");
const keys = @import("web/keys.zig");

var video_width: f32 = 1280;
var video_height: f32 = 720;
var video_scale: f32 = 1;

var global_arena: std.heap.ArenaAllocator = undefined;
var gpa: std.heap.GeneralPurposeAllocator(.{
    .safety = false,
}) = undefined;
var allocator: std.mem.Allocator = undefined;

var vg: nvg = undefined;

var prevt: f32 = 0;
var mx: f32 = 0;
var my: f32 = 0;
var blowup: bool = false;
var screenshot: bool = false;
var premult: bool = false;

const logger = std.log.scoped(.main);

export fn onInit() void {
    global_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    gpa = .{
        .backing_allocator = global_arena.allocator(),
    };
    allocator = gpa.allocator();

    wasm.global_allocator = allocator;

    vg = nvg.gl.init(allocator, .{}) catch {
        logger.err("Failed to create NanoVG", .{});
        return;
    };
}

export fn onResize(w: c_uint, h: c_uint, s: f32) void {
    video_width = @floatFromInt(w);
    video_height = @floatFromInt(h);
    video_scale = s;
    gl.glViewport(0, 0, @intFromFloat(s * video_width), @intFromFloat(s * video_height));
}

export fn onKeyDown(key: c_uint) void {
    if (key == keys.KEY_SPACE) blowup = !blowup;
    if (key == keys.KEY_S) screenshot = true;
    if (key == keys.KEY_P) premult = !premult;
}

export fn onMouseMove(x: i32, y: i32) void {
    mx = @floatFromInt(x);
    my = @floatFromInt(y);
}

export fn onAnimationFrame() void {
    const t = wasm.performanceNow() / 1000.0;
    const dt = t - prevt;
    prevt = t;

    if (premult) {
        gl.glClearColor(0, 0, 0, 0);
    } else {
        gl.glClearColor(0.3, 0.3, 0.32, 1.0);
    }
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

    vg.beginFrame(video_width, video_height, video_scale);

    // something
    _ = dt;

    vg.beginPath();
    vg.moveTo(100, 100);
    vg.lineTo(100, 200);
    vg.lineTo(200, 200);
    vg.fill();

    vg.endFrame();
}