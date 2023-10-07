const std = @import("std");
const keys = @import("web/keys.zig");
const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
const config = @import("config.zig");
const PhysicWorld = @import("PhysicWorld.zig");
const GameLogic = @import("GameLogic.zig");
const DuelMatchState = @import("DuelMatchState.zig");
const PlayerInput = @import("PlayerInput.zig");
const InputSource = @import("input.zig").InputSource;
const MatchEvent = @import("MatchEvent.zig");
const Vec2 = @import("Vec2.zig");

const logger = std.log.scoped(.DuelMatch);

const Self = @This();

physic_world: PhysicWorld,
input_sources: [constants.max_players]InputSource,
transformed_input: [constants.max_players]PlayerInput,
logic: GameLogic,
paused: bool = false,
events: std.ArrayList(MatchEvent),
remote: bool,

pub fn init(self: *Self, allocator: std.mem.Allocator, remote: bool) void {
    self.* = .{
        .physic_world = undefined,
        .input_sources = undefined,
        .transformed_input = undefined,
        .logic = undefined,
        .events = std.ArrayList(MatchEvent).init(allocator),
        .remote = remote,
    };
    self.logic.init(@embedFile("../data/rules/default.lua"), config.score_to_win);
    self.physic_world.init();

    self.paused = false;

    if (!remote) {
        self.physic_world.setEventCallback(self, onMatchEvent);
    }
}

pub fn setInputSources(self: *Self) void {
    self.input_sources[0].initLocal();
    self.input_sources[0].local.left_key = keys.KEY_A;
    self.input_sources[0].local.right_key = keys.KEY_D;
    self.input_sources[0].local.up_key = keys.KEY_W;

    const bot_script = @embedFile("../data/scripts/reduced.lua");
    self.input_sources[1].initScripted(bot_script, .right, config.right_script_strength, self);
}

fn onMatchEvent(self: *Self, event: MatchEvent) void {
    self.events.append(event) catch @panic("Failed to append event");
}

pub fn step(self: *Self) void {
    if (self.paused) return;

    self.transformed_input[0] = self.input_sources[0].getNextInput();
    self.transformed_input[1] = self.input_sources[1].getNextInput();

    if (self.remote) {
        @panic("TODO: implement transform input");
        // self.transformed_input[0] = self.logic.transformInput(self.transformed_input[0]);
        // self.transformed_input[1] = self.logic.transformInput(self.transformed_input[1]);
    }

    self.physic_world.step(self.transformed_input[0], self.transformed_input[1], self.logic.is_ball_valid, self.logic.is_game_running);
    self.logic.step(self.getState());

    for (self.events.items) |event| {
        switch (event.type) {
            .ball_hit_blob => self.logic.onBallHitsPlayer(event.side),
            .ball_hit_ground => {
                self.logic.onBallHitsGround(event.side);
                if (!self.logic.isBallValid()) {
                    self.physic_world.ball_velocity.scale(0.6, 0.6);
                }
            },
            .ball_hit_net => self.logic.onBallHitsNet(event.side),
            .ball_hit_net_top => self.logic.onBallHitsNet(null),
            .ball_hit_wall => self.logic.onBallHitsWall(event.side),

            .player_error, .reset_ball => {},
        }
    }

    if (self.logic.last_error) |error_side| {
        self.logic.last_error = null;
        self.onMatchEvent(MatchEvent.init(.player_error, error_side, 0));
        self.physic_world.ball_velocity.scale(0.6, 0.6);
    }

    if (!self.logic.isBallValid() and self.canStartRound(self.logic.serving_player.?)) {
        self.resetBall(self.logic.serving_player.?);
        self.logic.onServe();
        self.onMatchEvent(MatchEvent.init(.reset_ball, undefined, 0));
    }

    self.events.clearRetainingCapacity();
}

pub fn getBallActive(self: Self) bool {
    return self.logic.isGameRunning();
}

pub fn getBallVelocity(self: Self) Vec2 {
    return self.physic_world.ball_velocity;
}

pub fn getServingPlayer(self: Self) ?PlayerSide {
    return self.logic.serving_player;
}

pub fn setState(self: *Self, state: DuelMatchState) void {
    self.physic_world.setState(state.world_state);
    self.logic.setState(state.logic_state);
    self.transformed_input = state.player_input;
    // TODO: input source setInput?
}

pub fn getState(self: Self) DuelMatchState {
    return .{
        .world_state = self.physic_world.getState(),
        .logic_state = self.logic.getState(),
        .player_input = self.transformed_input,
    };
}

fn resetBall(self: *Self, side: PlayerSide) void {
    switch (side) {
        .left => {
            self.physic_world.ball_position = .{ .x = 200, .y = constants.standard_ball_height };
            self.physic_world.ball_angular_velocity = constants.standard_ball_angular_velocity;
        },
        .right => {
            self.physic_world.ball_position = .{ .x = 600, .y = constants.standard_ball_height };
            self.physic_world.ball_angular_velocity = -constants.standard_ball_angular_velocity;
        },
    }
    self.physic_world.ball_velocity = .{ .x = 0, .y = 0 };
}

fn canStartRound(self: Self, serving_player: PlayerSide) bool {
    const ball_velocity = self.physic_world.ball_velocity;
    return (self.physic_world.blobHitGround(serving_player) and ball_velocity.y < 1.5 and
        ball_velocity.y > -1.5 and self.physic_world.ball_position.y > 430);
}
