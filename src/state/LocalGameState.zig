const std = @import("std");
const DuelMatch = @import("../DuelMatch.zig");
const Renderer = @import("../Renderer.zig");

const Self = @This();

match: DuelMatch,

pub fn init(self: *Self, allocator: std.mem.Allocator) void {
    self.match.init(allocator, false);
}

pub fn step(self: *Self) void {
    self.match.step();
    Renderer.drawGame(self.match.getState());
}