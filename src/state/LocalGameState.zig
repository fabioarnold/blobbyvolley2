const std = @import("std");
const DuelMatch = @import("../DuelMatch.zig");
const Renderer = @import("../Renderer.zig");
const imgui = @import("../imgui.zig");

const Self = @This();

match: DuelMatch,
winner: bool,

pub fn init(self: *Self, allocator: std.mem.Allocator) void {
    self.* = .{
        .match = undefined,
        .winner = false,
    };
    self.match.init(allocator, false);
}

pub fn step(self: *Self) void {
    if (self.match.paused) {
        // gui pause
    } else if (self.winner) {
        imgui.label("Winner!", 500, 270);
    } else {
        self.match.step();
        if (self.match.logic.winning_player) |_| {
            self.winner = true;
        }
    }
}
