const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
const Vec2 = @import("Vec2.zig");
const PhysicState = @import("PhysicState.zig");
const GameLogicState = @import("GameLogicState.zig");
const PlayerInput = @import("PlayerInput.zig");

const Self = @This();

world_state: PhysicState,
logic_state: GameLogicState,
player_input: [constants.max_players]PlayerInput,

pub fn getBallPosition(self: Self) Vec2 {
    return self.world_state.ball_position;
}

pub fn getBallRotation(self: Self) f32 {
    return self.world_state.ball_rotation;
}

pub fn getBlobPosition(self: Self, player: PlayerSide) Vec2 {
    return self.world_state.blob_position[@intFromEnum(player)];
}

pub fn getHitcount(self: Self, player: PlayerSide) u32 {
    return self.logic_state.hit_count[player.index()];
}
