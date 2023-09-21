const std = @import("std");
const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;

const Self = @This();

left_score: u32,
right_score: u32,
hit_count: [constants.max_players]u32,
squish: [constants.max_players]u32,
squish_wall: u32 = 0,
squish_ground: u32 = 0,

serving_player: ?PlayerSide,
winning_player: ?PlayerSide,

is_ball_valid: bool = false,
is_game_running: bool = false,

pub fn swapSides(self: *Self) void {
    std.mem.swap(u32, &self.left_score, &self.right_score);
    std.mem.swap(u32, &self.hit_count[constants.player_left], &self.hit_count[constants.player_right]);
    std.mem.swap(u32, &self.hit_count[constants.player_left], &self.hit_count[constants.player_right]);

    if (self.serving_player == .left) {
        self.serving_player = .right;
    } else if (self.serving_player == .right) {
        self.serving_player = .left;
    }
}