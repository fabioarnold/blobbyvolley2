const std = @import("std");

const Renderer = @import("Renderer.zig");

const Object = struct {
    text: []const u8,
    x: f32,
    y: f32,
};

var objects: std.ArrayList(Object) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    objects = std.ArrayList(Object).init(allocator);
}

pub fn clear() void {
    objects.clearRetainingCapacity();
}

pub fn render() void {
    for (objects.items) |object| {
        Renderer.drawText(object.text, object.x, object.y);
    }
}

pub fn label(text: []const u8, x: f32, y: f32) void {
    objects.append(.{
        .text = text,
        .x = x,
        .y = y,
    }) catch unreachable;
}

pub fn button() bool {
    return false;
}
