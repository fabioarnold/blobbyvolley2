const std = @import("std");
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

pub fn swapSides(self: *Self) void {
    self.world_state.swapSides();
    self.logic_state.swapSides();
    std.mem.swap(PlayerInput, &self.player_input[0], &self.player_input[1]);
}

pub fn getBallPosition(self: Self) Vec2 {
    return self.world_state.ball_position;
}

pub fn getBallVelocity(self: Self) Vec2 {
    return self.world_state.ball_velocity;
}

pub fn getBallRotation(self: Self) f32 {
    return self.world_state.ball_rotation;
}

pub fn getServingPlayer(self: Self) ?PlayerSide {
    return self.logic_state.serving_player;
}

pub fn getBlobPosition(self: Self, player: PlayerSide) Vec2 {
    return self.world_state.blob_position[player.index()];
}

pub fn getBlobVelocity(self: Self, player: PlayerSide) Vec2 {
    return self.world_state.blob_velocity[player.index()];
}

pub fn getBallDown(self: Self) bool {
    return self.logic_state.is_ball_valid;
}

pub fn getBallActive(self: Self) bool {
	return self.logic_state.is_game_running;
}

pub fn getHitcount(self: Self, player: PlayerSide) u32 {
    return self.logic_state.hit_count[player.index()];
}

pub fn getScore(self: Self, player: PlayerSide) u32 {
    return switch (player) {
        .left => self.logic_state.left_score,
        .right => self.logic_state.right_score,
    };
}
