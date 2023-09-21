const std = @import("std");
const logger = std.log.scoped(.ScriptedInputSource);

const Vec2 = @import("Vec2.zig");
const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
const PlayerInput = @import("PlayerInput.zig");
const ScriptableComponent = @import("ScriptableComponent.zig");
const DuelMatch = @import("DuelMatch.zig");
const c = @import("c.zig");
const wasm = @import("web/wasm.zig");

const Self = @This();

// The time the bot waits after game start
const waiting_time = 1500;

start_time: f64 = 0,
wait_time: f64 = waiting_time,

side: PlayerSide,

// Difficulty setting of the AI. Small values mean stronger AI
difficulty: i32,

reaction_time: i32 = 0,
round_step_counter: i32 = 0,
old_opp_touches: u32 = 0,
old_own_touches: u32 = 0,
old_ball_vx: f32 = 0,

ball_pos_error: Vec2 = .{ .x = 0, .y = 0 },
ball_vel_error: Vec2 = .{ .x = 0, .y = 0 },
ball_pos_error_timer: i32 = 0,

blob_pos_error: i32 = 0,

random: std.rand.DefaultPrng,
match: *DuelMatch,

sc: ScriptableComponent,

pub fn init(script: []const u8, side: PlayerSide, difficulty: i32, match: *DuelMatch) Self {
    var self: Self = .{
        .sc = undefined,
        .side = side,
        .difficulty = difficulty,
        .match = match,
        .random = std.rand.DefaultPrng.init(0),
    };

    self.sc.init();

    self.start_time = wasm.dateNow();

    // set game constants
    self.sc.setGameConstants();
    self.sc.setGameFunctions();

    // push infos into script
    c.lua_pushnumber(self.sc.state, @as(f64, @floatFromInt(self.difficulty)) / 25.0);
    c.lua_setglobal(self.sc.state, "__DIFFICULTY");
    c.lua_pushinteger(self.sc.state, side.index());
    c.lua_setglobal(self.sc.state, "__SIDE");

    self.sc.runScript(@embedFile("../data/api.lua"));
    self.sc.runScript(@embedFile("../data/bot_api.lua"));
    self.sc.runScript(script);

    // check whether all required lua functions are available
    const has_step = self.sc.getLuaFunction("__OnStep");
    if (!has_step) {
        logger.err("Missing bot functions, check bot_api.lua!", .{});
        // 	std::string error_message = "Missing bot functions, check bot_api.lua! ";
        // 	std::cerr << "Lua Error: " << error_message << std::endl;

        // 	ScriptException except;
        // 	except.luaerror = error_message;
        // 	BOOST_THROW_EXCEPTION(except);
    }

    // clean up stack
    c.lua_pop(self.sc.state, c.lua_gettop(self.sc.state));

    return self;
}

pub fn getNextInput(self: *Self) PlayerInput {
    var state = self.match.getState();
    if (self.side == .right) {
        state.swapSides();
    }

    if (state.getBallPosition().x < 400) {
        self.ball_pos_error_timer -= 1;
        self.reaction_time -= 1;
    }

    // decrement counters regularly
    self.ball_pos_error_timer -= 1;
    self.reaction_time -= 1;

    // bot has not reacted yet
    if (self.reaction_time > 0 and self.difficulty > 0) {
        return .{};
    }

    // mis-estimated ball velocity handling
    if (self.ball_pos_error_timer > 0) {
        self.ball_pos_error.add(self.ball_vel_error);
    } else {
        self.ball_pos_error.clear();
        self.ball_vel_error.clear();
    }

    state.world_state.ball_position.add(self.ball_pos_error);
    state.world_state.ball_velocity.add(self.ball_vel_error);
    state.world_state.blob_position[constants.player_left].x += @floatFromInt(self.blob_pos_error);

    self.sc.setCachedMatchState(state);

    var serving: bool = false;
    // reset input
    c.lua_pushboolean(self.sc.state, @intFromBool(false));
    c.lua_setglobal(self.sc.state, "__WANT_LEFT");
    c.lua_pushboolean(self.sc.state, @intFromBool(false));
    c.lua_setglobal(self.sc.state, "__WANT_RIGHT");
    c.lua_pushboolean(self.sc.state, @intFromBool(false));
    c.lua_setglobal(self.sc.state, "__WANT_JUMP");

    _ = c.lua_getglobal(self.sc.state, "__OnStep");
    self.sc.callLuaFunction(0);

    if (!self.match.getBallActive() and
        // if no player is serving player, assume the left one is
        self.match.getServingPlayer() != .right)
    {
        serving = true;
    }

    // read input info from lua script
    _ = c.lua_getglobal(self.sc.state, "__WANT_LEFT");
    _ = c.lua_getglobal(self.sc.state, "__WANT_RIGHT");
    _ = c.lua_getglobal(self.sc.state, "__WANT_JUMP");
    const wantleft = c.lua_toboolean(self.sc.state, -3) != 0;
    const wantright = c.lua_toboolean(self.sc.state, -2) != 0;
    const wantjump = c.lua_toboolean(self.sc.state, -1) != 0;
    c.lua_pop(self.sc.state, 3);

    const stacksize = c.lua_gettop(self.sc.state);
    if (stacksize > 0) {
        logger.err("Warning: Stack messed up!", .{});
        // std::cerr << "Element on stack is a ";
        // std::cerr << c.lua_typename(self.sc.state, -1) << std::endl;
        c.lua_pop(self.sc.state, stacksize);
    }

    if (self.start_time + self.wait_time > wasm.dateNow() and serving)
        return .{};

    if (!self.match.getBallActive()) {
        if (!serving or self.difficulty < 15) {
            self.round_step_counter = 0;
            self.setInputDelay(0);
        }
    } else {
        self.round_step_counter += 1;
    }

    // whenever the opponent touches the ball, the bot pauses for a short, random amount of time
    // to orient itself. This time depends on the current difficulty level, and increases as the game
    // progresses.
    const opp_touches = state.getHitcount(.right);
    if (opp_touches != self.old_opp_touches) {
        self.old_opp_touches = opp_touches;
        // the number of opponent touches get reset to zero if the bot touches the ball -- ignore these cases
        if (opp_touches != 0) {
            const base_difficulty = @max(0, 2 * self.difficulty - 30);
            const max_difficulty = @min(75, base_difficulty + 2 * self.getCurrentDifficulty());
            const delay = self.random.random().intRangeAtMost(i32, base_difficulty, max_difficulty);
            // std::uniform_int_distribution<int> dist{base_difficulty, max_difficulty};
            self.setInputDelay(delay);
        }
    }

    const own_touches = state.getHitcount(.left);
    // for very easy difficulties, we modify the "perceived" x-coordinate of the bot's blob.
    // This needs to happen whenever the bot's blob touches the ball - if we had it also based
    // on `opp_touches`, then the errors while the ball is on the bot's side would be identical
    // for all its attempts to play the ball, which can look a bit stupid. This way, it is less
    // likely to lead directly to a point for the player, but still takes the "speed" out of the
    // bot's game.
    if (own_touches != self.old_own_touches) {
        self.old_own_touches = own_touches;
        // Note that this shift is one-sided, making the bot think it is closer to the wall than
        // it really is. This will result in it standing further to the net in reality, and being
        // less likely to play aggressive.
        const dice = self.random.random().intRangeAtMost(i32, 0, 100);
        if (dice < (self.difficulty - 15) * 8 and self.side == .left) {
            const error_dist = self.random.random().float(f32) * constants.ball_radius;
            self.blob_pos_error = @intFromFloat(-error_dist);
        } else {
            self.blob_pos_error = 0;
        }
    }

    // check if the x-velocity of the ball has changed. This only happens when the ball collides with something.
    // as this results in a change of trajectory of the ball, this is a relatively natural place for the bot to
    // change its estimated position and start moving the blob.
    // important: get the actual speed, not the simulated one. Otherwise, applying the error would trigger this condition
    // immediately again.
    const bv_x = self.match.getBallVelocity().x;
    if (bv_x != self.old_ball_vx) {
        self.old_ball_vx = bv_x;
        // don't apply an error after every collision -- results in very jittery bot.
        // instead, only do this in a fraction of the cases, up to 25% for very easy.
        const dist = self.random.random().intRangeAtMost(i32, 0, 100);
        if (dist < self.difficulty) {
            // generate a random amount, and random duration, for the error effect.
            const amount: f32 = @min(25.0,  @as(f32, @floatFromInt(self.getCurrentDifficulty()))) / 50.0 + @max(0,  @as(f32, @floatFromInt(self.difficulty)) - 5.0) / 25.0;
            const err_time = 25 + self.difficulty + @min(75, self.getCurrentDifficulty());
            self.setBallError(err_time, amount);
        }
    }

    var raw_input = PlayerInput{ .left = wantleft, .right = wantright, .up = wantjump };
    if (self.side == .right) {
        raw_input.swapSides();
    }
    return raw_input;
}

fn setInputDelay(self: *Self, delay: i32) void {
    self.reaction_time = @max(0, @max(delay, self.reaction_time));
}

fn getCurrentDifficulty(self: Self) i32 {
    const exchange_seconds = @divTrunc(self.round_step_counter, 75); // TODO: is this Hz?
    const difficulty_effect = @sqrt(@as(f32, @floatFromInt(self.difficulty)));
    // minimum game time until the bot starts making mistakes:
    // ~5 minutes at highest difficulty, 10 seconds for very easy.
    const min_duration: i32 = 300 - @as(i32, @intFromFloat(@as(f32, difficulty_effect * 58.0)));
    const offset_seconds = @max(0, exchange_seconds - min_duration);
    const diff_mod = @divTrunc(offset_seconds * self.difficulty, 25);
    return diff_mod;
}

fn setBallError(self: *Self, duration: i32, amount: f32) void {
    self.ball_pos_error_timer = duration;
    const angle = 2.0 * std.math.pi * self.random.random().float(f32);
    self.ball_vel_error.x = @sin(angle) * amount;
    self.ball_vel_error.y = @cos(angle) * amount;
    self.ball_pos_error = self.ball_vel_error;
    self.ball_pos_error.scaleScalar(5);
}
