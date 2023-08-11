const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
const GameLogicState = @import("GameLogicState.zig");
const DuelMatchState = @import("DuelMatchState.zig");

const Self = @This();

score_to_win: u32,
scores: [constants.max_players]u32 = [_]u32{0, 0},
touches: [constants.max_players]u32 = [_]u32{0, 0},
squish: [constants.max_players]u32 = [_]u32{0, 0},
squish_wall: u32 = 0,
squish_ground: u32 = 0,

last_error: ?PlayerSide = null,
serving_player: ?PlayerSide = null,
winning_player: ?PlayerSide = null,

is_ball_valid: bool = false,
is_game_running: bool = false,

pub fn init(self: *Self, score_to_win: u32) void {
    self.* = .{
        .score_to_win = score_to_win,
    };
}

pub fn step(self: *Self, state: DuelMatchState) void {
    _ = self;
    _ = state;
    // if (self.lua) {
    //     LuaOnGameHandler(state);
    // }
}

pub fn getState(self: Self) GameLogicState {
    return .{
        .left_score = self.scores[0],
        .right_score = self.scores[1],
        .hit_count = self.touches,
        .serving_player = self.serving_player,
        .winning_player = self.winning_player,
        .squish = self.squish,
        .squish_wall = self.squish_wall,
        .squish_ground = self.squish_ground,
        .is_ball_valid = self.is_ball_valid,
        .is_game_running = self.is_game_running,
    };
}