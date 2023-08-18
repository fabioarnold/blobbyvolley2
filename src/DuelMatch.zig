const keys = @import("web/keys.zig");
const constants = @import("constants.zig");
const config = @import("config.zig");
const PhysicWorld = @import("PhysicWorld.zig");
const GameLogic = @import("GameLogic.zig");
const DuelMatchState = @import("DuelMatchState.zig");
const PlayerInput = @import("PlayerInput.zig");
const InputSource = @import("InputSource.zig");

const Self = @This();

physic_world: PhysicWorld,
logic: GameLogic,
input_sources: [constants.max_players]InputSource,
transformed_input: [constants.max_players]PlayerInput,
paused: bool,

pub fn init(self: *Self) void {
    self.physic_world.init();
    self.logic.init(@embedFile("../data/rules/default.lua"), config.score_to_win);
    self.input_sources[0] = InputSource{
        .left_key = keys.KEY_A,
        .right_key = keys.KEY_D,
        .up_key = keys.KEY_W,
    };
    self.input_sources[1] = InputSource{};
    self.paused = false;
}

pub fn step(self: *Self) void {
    if (self.paused) return;

    self.transformed_input[0] = self.input_sources[0].updateInput();
    self.transformed_input[1] = self.input_sources[1].updateInput();

    self.physic_world.step(self.transformed_input[0], self.transformed_input[1], self.logic.is_ball_valid, self.logic.is_game_running);
    self.logic.step(self.getState());
}

pub fn getState(self: Self) DuelMatchState {
    return .{
        .world_state = self.physic_world.getState(),
        .logic_state = self.logic.getState(),
        .player_input = self.transformed_input,
    };
}