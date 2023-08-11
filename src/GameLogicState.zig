const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;

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