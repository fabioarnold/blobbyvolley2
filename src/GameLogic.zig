const std = @import("std");
const logger = std.log.scoped(.GameLogic);

const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
const Clock = @import("Clock.zig");
const GameLogicState = @import("GameLogicState.zig");
const DuelMatchState = @import("DuelMatchState.zig");
const ScriptableComponent = @import("ScriptableComponent.zig");
const c = @import("c.zig");

const GameLogic = @This();
const Self = @This();

const squish_tolerance = 11;

score_to_win: u32,
scores: [constants.max_players]u32 = [_]u32{ 0, 0 },
touches: [constants.max_players]u32 = [_]u32{ 0, 0 },
squish: [constants.max_players]u32 = [_]u32{ 0, 0 },
squish_wall: u32 = 0,
squish_ground: u32 = 0,

last_error: ?PlayerSide = null,
serving_player: ?PlayerSide = null,
winning_player: ?PlayerSide = null,

is_ball_valid: bool = true,
is_game_running: bool = false,

clock: Clock,

sc: ScriptableComponent,

pub fn init(self: *Self, rules_script: []const u8, score_to_win: u32) void {
    self.* = .{
        .score_to_win = score_to_win,
        .clock = undefined,
        .sc = undefined,
    };
    self.clock.init();
    self.clock.start();
    self.sc.init();

    c.lua_pushlightuserdata(self.sc.state, self);
    c.lua_setglobal(self.sc.state, "__GAME_LOGIC_POINTER");

    // todo: use lua registry instead of globals!
    c.lua_pushnumber(self.sc.state, @floatFromInt(score_to_win));
    c.lua_setglobal(self.sc.state, "SCORE_TO_WIN");

    self.sc.setGameConstants();
    self.sc.setGameFunctions();

    // add functions
    c.lua_register(self.sc.state, "score", luaScore);
    c.lua_register(self.sc.state, "mistake", luaMistake);
    c.lua_register(self.sc.state, "servingplayer", luaGetServingPlayer);
    c.lua_register(self.sc.state, "time", luaGetGameTime);
    c.lua_register(self.sc.state, "isgamerunning", luaIsGameRunning);

    // now load script file
    self.sc.runScript(@embedFile("../data/api.lua"));
    self.sc.runScript(@embedFile("../data/rules_api.lua"));
    self.sc.runScript(rules_script);

    _ = c.lua_getglobal(self.sc.state, "SCORE_TO_WIN");
    self.score_to_win = @intCast(c.lua_to_int(self.sc.state, -1));
    c.lua_pop(self.sc.state, 1);

    _ = c.lua_getglobal(self.sc.state, "__AUTHOR__");
    const author = c.lua_tostring(self.sc.state, -1);
    // mAuthor = ( author ? author : "unknown author" );
    c.lua_pop(self.sc.state, 1);

    _ = c.lua_getglobal(self.sc.state, "__TITLE__");
    const title = c.lua_tostring(self.sc.state, -1);
    // mTitle = ( title ? title : "untitled script" );
    c.lua_pop(self.sc.state, 1);

    logger.info("loaded rules {s} by {s}", .{ title, author });
    // std::cout << "loaded rules "<< mTitle<< " by " << mAuthor << " from " << mSourceFile << std::endl;
}

pub fn step(self: *Self, state: DuelMatchState) void {
    self.clock.step();
    if (self.clock.isRunning()) {
        self.squish[0] -|= 1;
        self.squish[1] -|= 1;
        self.squish_wall -|= 1;
        self.squish_ground -|= 1;

        self.onGameHandler(state);
    }
}

pub fn onServe(self: *Self) void {
    self.is_ball_valid = true;
    self.is_game_running = false;
}

pub fn onBallHitsGround(self: *Self, side: PlayerSide) void {
    if (!self.isGroundCollisionValid()) return;

    self.squish_ground = squish_tolerance;
    self.touches[side.other().index()] = 0;

    self.onBallHitsGroundHandler(side);
}

pub fn isBallValid(self: Self) bool {
    return self.is_ball_valid;
}

pub fn isGameRunning(self: Self) bool {
    return self.is_game_running;
}

pub fn isCollisionValid(self: Self, side: PlayerSide) bool {
    return self.squish[side.index()] == 0;
}

pub fn isGroundCollisionValid(self: Self) bool {
    return self.squish_ground == 0 and self.isBallValid();
}

pub fn isWallCollisionValid(self: Self) bool {
    return self.squish_wall == 0 and self.isBallValid();
}

pub fn onBallHitsPlayer(self: *Self, side: PlayerSide) void {
    if (!self.isCollisionValid(side)) return;

    self.squish[side.index()] = squish_tolerance;
    // now, the other blobby has to accept the new hit!
    self.squish[side.other().index()] = 0;

    self.is_game_running = true;

    // count the touches
    self.touches[side.index()] += 1;
    self.onBallHitsPlayerHandler(side);

    // reset other players touches after OnBallHitsPlayerHandler is called, so
    // we have still access to its old value inside the handler function
    self.touches[side.other().index()] = 0;
}

pub fn onBallHitsWall(self: *Self, side: PlayerSide) void {
    if (!self.isWallCollisionValid()) return;

    self.squish_wall = squish_tolerance;

    self.onBallHitsWallHandler(side);
}

pub fn onBallHitsNet(self: *Self, side: ?PlayerSide) void {
    if (!self.isWallCollisionValid()) return;

    self.squish_wall = squish_tolerance;

    self.onBallHitsNetHandler(side);
}

fn score(self: *Self, side: PlayerSide, amount: i32) void {
    if (amount < 0) {
        self.scores[side.index()] -|= @intCast(-amount);
    } else {
        self.scores[side.index()] += @intCast(amount);
    }

    self.winning_player = self.checkWin();
}

fn onError(self: *Self, error_side: PlayerSide, serve_side: PlayerSide) void {
    self.last_error = error_side;
    self.is_ball_valid = false;

    self.touches[0] = 0;
    self.touches[1] = 0;
    self.squish[0] = 0;
    self.squish[1] = 0;
    self.squish_wall = 0;
    self.squish_ground = 0;

    self.serving_player = serve_side;
}

fn checkWinFallback(self: Self) ?PlayerSide {
    const left = self.scores[constants.player_left];
    const right = self.scores[constants.player_right];
    if (left >= self.score_to_win and left >= right + 2) return .left;
    if (right >= self.score_to_win and right >= left + 2) return .right;
    return null;
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

// LuaGameLogic

fn checkWin(self: Self) ?PlayerSide {
    if (self.sc.getLuaFunction("IsWinning")) {
        c.lua_pushnumber(self.sc.state, @floatFromInt(self.scores[constants.player_left]));
        c.lua_pushnumber(self.sc.state, @floatFromInt(self.scores[constants.player_right]));
        if (c.lua_pcall(self.sc.state, 2, 1, 0) != 0) {
            const error_string = c.lua_tostring(self.sc.state, -1);
            logger.err("error in IsWinning: {s}", .{error_string});
        }
        const won = c.lua_toboolean(self.sc.state, -1) != 0;
        c.lua_pop(self.sc.state, 1);
        if (won) {
            if (self.scores[constants.player_left] > self.scores[constants.player_right]) {
                return .left;
            }
            if (self.scores[constants.player_right] > self.scores[constants.player_left]) {
                return .right;
            }
        }

        return null;
    } else {
        return self.checkWinFallback();
    }
}

fn onBallHitsPlayerHandler(self: *Self, side: PlayerSide) void {
    self.updateLuaLogicState();

    if (self.sc.getLuaFunction("OnBallHitsPlayer")) {
        c.lua_pushnumber(self.sc.state, @floatFromInt(side.index()));
        if (c.lua_pcall(self.sc.state, 1, 0, 0) != 0) {
            const error_string = c.lua_tostring(self.sc.state, -1);
            logger.err("error in OnBallHitsPlayer: {s}", .{error_string});
        }
    } else {
        @panic("implement fallback for onBallHitsPlayerHandler");
    }
}

fn onBallHitsWallHandler(self: *Self, side: PlayerSide) void {
    self.updateLuaLogicState();

    if (self.sc.getLuaFunction("OnBallHitsWall")) {
        c.lua_pushnumber(self.sc.state, @floatFromInt(side.index()));
        if (c.lua_pcall(self.sc.state, 1, 0, 0) != 0) {
            const error_string = c.lua_tostring(self.sc.state, -1);
            logger.err("error in OnBallHitsWall: {s}", .{error_string});
        }
    } else {
        @panic("implement fallback for onBallHitsWallHandler");
    }
}

fn onBallHitsNetHandler(self: *Self, side: ?PlayerSide) void {
    self.updateLuaLogicState();

    if (self.sc.getLuaFunction("OnBallHitsNet")) {
        if (side) |s| {
            c.lua_pushnumber(self.sc.state, @floatFromInt(s.index()));
        } else {
            c.lua_pushnumber(self.sc.state, constants.player_none);
        }
        if (c.lua_pcall(self.sc.state, 1, 0, 0) != 0) {
            const error_string = c.lua_tostring(self.sc.state, -1);
            logger.err("error in OnBallHitsNet: {s}", .{error_string});
        }
    } else {
        @panic("implement fallback for onBallHitsNetHandler");
    }
}

fn onBallHitsGroundHandler(self: *Self, side: PlayerSide) void {
    self.updateLuaLogicState();

    if (self.sc.getLuaFunction("OnBallHitsGround")) {
        c.lua_pushnumber(self.sc.state, @floatFromInt(side.index()));
        if (c.lua_pcall(self.sc.state, 1, 0, 0) != 0) {
            const error_string = c.lua_tostring(self.sc.state, -1);
            logger.err("error in OnBallHitsGround: {s}", .{error_string});
        }
    } else {
        @panic("implement fallback for onBallHitsGroundHandler");
    }
}

fn onGameHandler(self: *Self, state: DuelMatchState) void {
    self.sc.cached_state = state;
    if (self.sc.getLuaFunction("OnGame")) {
        if (c.lua_pcall(self.sc.state, 0, 0, 0) != 0) {
            const error_string = c.lua_tostring(self.sc.state, -1);
            logger.err("error in OnGame: {s}", .{error_string});
        }
    } else {
        @panic("implement fallback for onGameHandler");
    }
}

fn getGameLogic(state: ?*c.lua_State) *GameLogic {
    _ = c.lua_getglobal(state, "__GAME_LOGIC_POINTER");
    const gl: *GameLogic = @alignCast(@ptrCast(c.lua_touserdata(state, -1)));
    c.lua_pop(state, 1);
    return gl;
}

fn updateLuaLogicState(self: *Self) void {
    var state = self.sc.cached_state;
    state.logic_state = self.getState();
    self.sc.cached_state = state;
}

fn luaMistake(state: ?*c.lua_State) callconv(.C) c_int {
    const amount = c.lua_to_int(state, -1);
    c.lua_pop(state, 1);
    const serveSide: PlayerSide = @enumFromInt(@as(u1, @intCast(c.lua_to_int(state, -1))));
    c.lua_pop(state, 1);
    const mistakeSide: PlayerSide = @enumFromInt(@as(u1, @intCast(c.lua_to_int(state, -1))));
    c.lua_pop(state, 1);
    const gl = getGameLogic(state);

    gl.score(mistakeSide.other(), amount);
    gl.onError(mistakeSide, serveSide);
    return 0;
}

fn luaScore(state: ?*c.lua_State) callconv(.C) c_int {
    const amount = c.lua_to_int(state, -1);
    c.lua_pop(state, 1);
    const player: PlayerSide = @enumFromInt(@as(u1, @intCast(c.lua_to_int(state, -1))));
    c.lua_pop(state, 1);
    const gl = getGameLogic(state);

    gl.score(player, amount);
    return 0;
}

fn luaGetServingPlayer(state: ?*c.lua_State) callconv(.C) c_int {
    const gl = getGameLogic(state);
    if (gl.serving_player) |serving_player| {
        c.lua_pushnumber(state, @floatFromInt(serving_player.index()));
    } else {
        c.lua_pushnumber(state, constants.player_none);
    }
    return 1;
}

fn luaGetGameTime(state: ?*c.lua_State) callconv(.C) c_int {
    const gl = getGameLogic(state);
    c.lua_pushnumber(state, gl.clock.game_time * 0.001); // seconds
    return 1;
}

fn luaIsGameRunning(state: ?*c.lua_State) callconv(.C) c_int {
    const gl = getGameLogic(state);
    c.lua_pushboolean(state, @intFromBool(gl.is_game_running));
    return 1;
}
