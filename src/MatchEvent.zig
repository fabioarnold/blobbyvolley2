const PlayerSide = @import("constants.zig").PlayerSide;

const Type = enum {
    // physics events
    ball_hit_blob,
    ball_hit_wall,
    ball_hit_ground,
    ball_hit_net,
    ball_hit_net_top,
    // logic events
    player_error,
    reset_ball,
};

type: Type,
side: PlayerSide,
intensity: f32,

pub fn init(@"type": Type, side: PlayerSide, intensity: f32) @This() {
    return .{
        .type = @"type",
        .side = side,
        .intensity = intensity,
    };
}
