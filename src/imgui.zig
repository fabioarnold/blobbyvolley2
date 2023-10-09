const std = @import("std");

const nvg = @import("nanovg");

const Renderer = @import("Renderer.zig");

const ObjectType = enum {
    label,
    button,
};

const Object = struct {
    obj_type: ObjectType,
    text: []const u8,
    x: f32,
    y: f32,
    alignment: nvg.TextAlign,
};

pub var mouse_x: f32 = 0;
pub var mouse_y: f32 = 0;
pub var click: bool = false;

var objects: std.ArrayList(Object) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    objects = std.ArrayList(Object).init(allocator);
}

pub fn clear() void {
    objects.clearRetainingCapacity();
}

pub fn render() void {
    for (objects.items) |object| {
        Renderer.drawText(object.text, object.x, object.y, object.alignment);
    }
}

pub fn label(text: []const u8, x: f32, y: f32, alignment: nvg.TextAlign) void {
    objects.append(.{
        .obj_type = .label,
        .text = text,
        .x = x,
        .y = y,
        .alignment = alignment,
    }) catch unreachable;
}

pub fn button(text: []const u8, x: f32, y: f32, alignment: nvg.TextAlign) bool {
    objects.append(.{
        .obj_type = .button,
        .text = text,
        .x = x,
        .y = y,
        .alignment = alignment,
    }) catch unreachable;
    return click and Renderer.pointInText(mouse_x, mouse_y, text, x, y, alignment);
}
