const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
const Vec2 = @import("Vec2.zig");
const PhysicWorld = @import("PhysicWorld.zig");
const GameLogicState = @import("GameLogicState.zig");
const PlayerInput = @import("PlayerInput.zig");

const Self = @This();

world_state: PhysicWorld,
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