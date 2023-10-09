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
const PhysicState = @import("PhysicState.zig");
const Renderer = @import("Renderer.zig");
const imgui = @import("imgui.zig");

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

var game_state: LocalGameState = undefined;

var menu: bool = true;
var menu_alpha: f32 = 1;

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
    imgui.init(allocator);
    game_state.init(allocator);
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

export fn onMouseMove(x: f32, y: f32) void {
    imgui.mouse_x = x;
    imgui.mouse_y = y;
}

export fn onMouseClick(button: i32) void {
    if (button == 0) {
        imgui.click = true;
    }
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

fn getPhysicState() PhysicState {
    return game_state.match.physic_world.getState();
}

export fn getBallX() f32 {
    return getPhysicState().ball_position.x;
}

export fn getBallY() f32 {
    return getPhysicState().ball_position.y;
}

export fn getBallRotation() f32 {
    return getPhysicState().ball_rotation;
}

export fn getMenuAlpha() f32 {
    return menu_alpha;
}

export fn step() void {
    imgui.clear();

    const a = @max(0, menu_alpha * 3 - 2);
    const alpha = 1.0 - (1.0 - a) * (1.0 - a);

    imgui.label("Blobby Volley 3D", 400, alpha * 200 - 50, .{ .horizontal = .center });

    if (imgui.button("Vs Player", alpha * 400 - 300, 300, .{})) {
        menu = false;
    }

    if (imgui.button("Vs Bot", alpha * 400 - 300, 400, .{})) {
        menu = false;
    }

    if (menu) {
        if (menu_alpha < 1) {
            menu_alpha += 1.0 / 60.0;
            if (menu_alpha > 1) {
                menu_alpha = 1;
            }
        }
    } else {
        if (menu_alpha > 0) {
            menu_alpha -= 1.0 / 60.0;
            if (menu_alpha < 0) {
                menu_alpha = 0;
            }
        }
        game_state.step();
    }
}

export fn onAnimationFrame() void {
    // const t = wasm.performanceNow() / 1000.0;
    // const dt = t - prevt;
    // prevt = t;

    const vg = Renderer.vg;
    vg.beginFrame(video_width, video_height, video_scale);
    scaleToFit();

    Renderer.drawGame(game_state.match.getState(), menu_alpha == 0);

    imgui.render();
    imgui.click = false;

    vg.endFrame();
}
