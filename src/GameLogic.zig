const std = @import("std");
const logger = std.log.scoped(.GameLogic);

const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
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

is_ball_valid: bool = false,
is_game_running: bool = false,

sc: ScriptableComponent,

pub fn init(self: *Self, rules_script: []const u8, score_to_win: u32) void {
    self.* = .{
        .score_to_win = score_to_win,
        .sc = undefined,
    };
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
    // self.sc.openScript("api");
    // self.sc.openScript("rules_api");
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
    _ = self;
    _ = state;
    // if (self.lua) {
    //     LuaOnGameHandler(state);
    // }
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

fn checkWin(self: Self) ?PlayerSide {
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

fn getGameLogic(state: ?*c.lua_State) *GameLogic {
    _ = c.lua_getglobal(state, "__GAME_LOGIC_POINTER");
    const gl: *GameLogic = @alignCast(@ptrCast(c.lua_touserdata(state, -1)));
    c.lua_pop(state, 1);
    return gl;
}

fn luaMistake(state: ?*c.lua_State) callconv(.C) c_int {
    const amount = c.lua_to_int(state, -1);
    c.lua_pop(state, 1);
    const serveSide: PlayerSide = @enumFromInt(@as(u1, @intCast(c.lua_to_int(state, -1))));
    c.lua_pop(state, 1);
    const mistakeSide: PlayerSide = @enumFromInt(@as(u1,@intCast(c.lua_to_int(state, -1))));
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
    _ = gl;
    // c.lua_pushnumber(state, gl.getClock().getTime().count());
    return 1;
}

fn luaIsGameRunning(state: ?*c.lua_State) callconv(.C) c_int {
    const gl = getGameLogic(state);
    c.lua_pushboolean(state, @intFromBool(gl.is_game_running));
    return 1;
}
