const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;

left_score: u32,
right_score: u32,
hit_count: [constants.max_players]u32,
serving_player: PlayerSide,
winning_player: ?PlayerSide = null,