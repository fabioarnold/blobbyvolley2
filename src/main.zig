const std = @import("std");
const logger = std.log.scoped(.main);

const nvg = @import("nanovg");

const wasm = @import("web/wasm.zig");
pub const std_options = struct {
    pub const log_level = .info;
    pub const logFn = wasm.log;
};
const gl = @import("web/webgl.zig");
const keys = @import("web/keys.zig");

const LocalGameState = @import("state/LocalGameState.zig");
const Renderer = @import("Renderer.zig");

var video_width: f32 = 1280;
var video_height: f32 = 720;
var video_scale: f32 = 1;

const game_width = 800;
const game_height = 600;

var global_arena: std.heap.ArenaAllocator = undefined;
var gpa: std.heap.GeneralPurposeAllocator(.{
    .safety = false,
}) = undefined;
var allocator: std.mem.Allocator = undefined;

var prevt: f32 = 0;
var mx: f32 = 0;
var my: f32 = 0;

var game_state: LocalGameState = undefined;

export fn onInit() void {
    global_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    gpa = .{
        .backing_allocator = global_arena.allocator(),
    };
    allocator = gpa.allocator();

    wasm.global_allocator = allocator;

    Renderer.init(allocator) catch {
        logger.err("Failed to init Renderer", .{});
        return;
    };

    Renderer.load();
    game_state.init();
}

export fn onResize(w: c_uint, h: c_uint, s: f32) void {
    video_width = @floatFromInt(w);
    video_height = @floatFromInt(h);
    video_scale = s;
    gl.glViewport(0, 0, @intFromFloat(s * video_width), @intFromFloat(s * video_height));
}

export fn onKeyDown(key: c_uint) void {
    _ = key;
}

export fn onMouseMove(x: i32, y: i32) void {
    mx = @floatFromInt(x);
    my = @floatFromInt(y);
}

fn scaleToFit() void {
    const vg = Renderer.vg;
    const sx = video_width / game_width;
    const sy = video_height / game_height;
    if (sx < sy) {
        vg.translate(0, 0.5 * (video_height - sx * game_height));
        vg.scale(sx, sx);
    } else {
        vg.translate(0.5 * (video_width - sy * game_width), 0);
        vg.scale(sy, sy);
    }
}

export fn onAnimationFrame() void {
    const t = wasm.performanceNow() / 1000.0;
    const dt = t - prevt;
    prevt = t;

    gl.glClearColor(0, 0, 0, 0);
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

    const vg = Renderer.vg;
    vg.beginFrame(video_width, video_height, video_scale);
    scaleToFit();

    _ = dt;
    game_state.step();

    vg.endFrame();
}