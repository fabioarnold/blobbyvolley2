const std = @import("std");
const logger = std.log.scoped(.ScriptableComponent);

const c = @import("c.zig");
const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
const Vec2 = @import("Vec2.zig");
const DuelMatchState = @import("DuelMatchState.zig");
const PhysicWorld = @import("PhysicWorld.zig");

const Self = @This();

state: *c.lua_State,

cached_state: DuelMatchState,

dummy_world: PhysicWorld,

pub fn init(self: *Self) void {
    self.state = c.luaL_newstate().?;

    self.dummy_world.init();

    // register this in the lua registry
    _ = c.lua_pushliteral(self.state, "__C++_ScriptComponent__");
    c.lua_pushlightuserdata(self.state, @ptrCast(self));
    c.lua_settable(self.state, c.LUA_REGISTRYINDEX);

    // open math lib
    c.luaL_requiref(self.state, "math", c.luaopen_math, 1);
    c.luaL_requiref(self.state, "base", c.luaopen_base, 1);
}

pub fn runScript(self: Self, script: []const u8) void {
    _ = c.luaL_loadstring(self.state, script.ptr);
    _ = c.lua_pcall(self.state, 0, 0, 0);
}

pub fn setGameConstants(self: Self) void {
    self.setLuaGlobal("CONST_FIELD_WIDTH", constants.right_plane);
    self.setLuaGlobal("CONST_GROUND_HEIGHT", 600 - constants.ground_plane_height_max);
    self.setLuaGlobal("CONST_BALL_GRAVITY", -constants.ball_gravitation);
    self.setLuaGlobal("CONST_BALL_RADIUS", constants.ball_radius);
    self.setLuaGlobal("CONST_BLOBBY_JUMP", -constants.blobby_jump_acceleration);
    self.setLuaGlobal("CONST_BLOBBY_BODY_RADIUS", constants.blobby_lower_radius);
    self.setLuaGlobal("CONST_BLOBBY_HEAD_RADIUS", constants.blobby_upper_radius);
    self.setLuaGlobal("CONST_BLOBBY_HEAD_OFFSET", constants.blobby_upper_sphere);
    self.setLuaGlobal("CONST_BLOBBY_BODY_OFFSET", -constants.blobby_lower_sphere);
    self.setLuaGlobal("CONST_BALL_HITSPEED", constants.ball_collision_velocity);
    self.setLuaGlobal("CONST_BLOBBY_HEIGHT", constants.blobby_height);
    self.setLuaGlobal("CONST_BLOBBY_GRAVITY", -constants.gravitation);
    self.setLuaGlobal("CONST_BLOBBY_SPEED", constants.blobby_speed);
    self.setLuaGlobal("CONST_NET_HEIGHT", 600 - constants.net_sphere_position);
    self.setLuaGlobal("CONST_NET_RADIUS", constants.net_radius);
    self.setLuaGlobal("NO_PLAYER", constants.player_none);
    self.setLuaGlobal("LEFT_PLAYER", constants.player_left);
    self.setLuaGlobal("RIGHT_PLAYER", constants.player_right);
}

pub fn setGameFunctions(self: *Self) void {
    c.lua_register(self.state, "get_ball_pos", get_ball_pos);
    c.lua_register(self.state, "get_ball_vel", get_ball_vel);
    c.lua_register(self.state, "get_blob_pos", get_blob_pos);
    c.lua_register(self.state, "get_blob_vel", get_blob_vel);
    c.lua_register(self.state, "get_score", get_score);
    c.lua_register(self.state, "get_touches", get_touches);
    c.lua_register(self.state, "is_ball_valid", get_ball_valid);
    c.lua_register(self.state, "is_game_running", get_game_running);
    c.lua_register(self.state, "get_serving_player", get_serving_player);
    c.lua_register(self.state, "simulate", simulate_steps);
    c.lua_register(self.state, "simulate_until", simulate_until);
}

fn setLuaGlobal(self: Self, name: []const u8, value: f64) void {
    c.lua_pushnumber(self.state, value);
    c.lua_setglobal(self.state, name.ptr);
}

pub fn getLuaFunction(self: Self, name: []const u8) bool {
    _ = c.lua_getglobal(self.state, name.ptr);
    if (!c.lua_isfunction(self.state, -1)) {
        c.lua_pop(self.state, 1);
        return false;
    }
    return true;
}

pub fn callLuaFunction(self: Self, arg_count: i32) void {
    if (c.lua_pcall(self.state, arg_count, 0, 0) != 0) {
        logger.err("Lua Error: {s}", .{c.lua_tostring(self.state, -1)});
    }
}

fn getScriptComponent(state: ?*c.lua_State) *Self {
    _ = c.lua_pushliteral(state, "__C++_ScriptComponent__");
    _ = c.lua_gettable(state, c.LUA_REGISTRYINDEX);
    const result = c.lua_touserdata(state, -1);
    c.lua_pop(state, 1);
    return @alignCast(@ptrCast(result));
}

fn getMatchState(state: ?*c.lua_State) *DuelMatchState {
    const sc = getScriptComponent(state);
    return &sc.cached_state;
}

fn getWorld(state: ?*c.lua_State) *PhysicWorld {
    const sc = getScriptComponent(state);
    return &sc.dummy_world;
}

const VectorType = enum {
    position,
    velocity,
};

fn lua_pushvector(state: ?*c.lua_State, v: Vec2, vector_type: VectorType) c_int {
    if (vector_type == .position) {
        c.lua_pushnumber(state, v.x);
        c.lua_pushnumber(state, -v.y);
    } else if (vector_type == .velocity) {
        c.lua_pushnumber(state, v.x);
        c.lua_pushnumber(state, 600 - v.y);
    }
    return 2;
}

// standard lua functions
fn get_ball_pos(state: ?*c.lua_State) callconv(.C) c_int {
    return lua_pushvector(state, getMatchState(state).getBallPosition(), .position);
}

fn get_ball_vel(state: ?*c.lua_State) callconv(.C) c_int {
    return lua_pushvector(state, getMatchState(state).getBallVelocity(), .velocity);
}

fn get_blob_pos(state: ?*c.lua_State) callconv(.C) c_int {
    const s = getMatchState(state);
    const side: PlayerSide = @enumFromInt(c.lua_to_int(state, -1));
    c.lua_pop(state, 1);
    return lua_pushvector(state, s.getBlobPosition(side), .position);
}

fn get_blob_vel(state: ?*c.lua_State) callconv(.C) c_int {
    const s = getMatchState(state);
    const side: PlayerSide = @enumFromInt(c.lua_to_int(state, -1));
    c.lua_pop(state, 1);
    return lua_pushvector(state, s.getBlobVelocity(side), .velocity);
}

fn get_score(state: ?*c.lua_State) callconv(.C) c_int {
    const s = getMatchState(state);
    const side: PlayerSide = @enumFromInt(c.lua_to_int(state, -1));
    c.lua_pop(state, 1);
    c.lua_pushinteger(state, s.getScore(side));
    return 1;
}

fn get_touches(state: ?*c.lua_State) callconv(.C) c_int {
    const s = getMatchState(state);
    const side: PlayerSide = @enumFromInt(c.lua_to_int(state, -1));
    logger.info("get_touches: {}", .{side});
    c.lua_pop(state, 1);
    c.lua_pushinteger(state, s.getHitcount(side));
    return 1;
}

fn get_ball_valid(state: ?*c.lua_State) callconv(.C) c_int {
    const s = getMatchState(state);
    c.lua_pushboolean(state, @intFromBool(!s.getBallDown()));
    return 1;
}

fn get_game_running(state: ?*c.lua_State) callconv(.C) c_int {
    const s = getMatchState(state);
    c.lua_pushboolean(state, @intFromBool(s.getBallActive()));
    return 1;
}

fn get_serving_player(state: ?*c.lua_State) callconv(.C) c_int {
    const s = getMatchState(state);
    if (s.getServingPlayer()) |serving_player| {
        c.lua_pushinteger(state, serving_player.index());
    } else {
        c.lua_pushinteger(state, constants.player_none);
    }
    return 1;
}

fn simulate_steps(state: ?*c.lua_State) callconv(.C) c_int {
    // todo should we gather and return all events that happen to the ball on the way?
    const world = getWorld(state);
    // get the initial ball settings
    _ = c.lua_checkstack(state, 5);
    const steps = c.lua_tointeger(state, 1);
    const x: f32 = @floatCast(c.lua_tonumber(state, 2));
    const y: f32 = @floatCast(c.lua_tonumber(state, 3));
    const vx: f32 = @floatCast(c.lua_tonumber(state, 4));
    const vy: f32 = @floatCast(c.lua_tonumber(state, 5));
    c.lua_pop(state, 5);

    world.ball_position = .{ .x = x, .y = 600 - y };
    world.ball_velocity = .{ .x = vx, .y = -vy };
    var i: usize = 0;
    while (i < steps) : (i += 1) {
        // set ball valid to false to ignore blobby bounces
        world.step(.{}, .{}, false, true);
    }

    var ret = lua_pushvector(state, world.ball_position, .position);
    ret += lua_pushvector(state, world.ball_velocity, .velocity);
    return ret;
}

fn simulate_until(state: ?*c.lua_State) callconv(.C) c_int {
    // todo should we gather and return all events that happen to the ball on the way?
    const world = getWorld(state);
    // get the initial ball settings
    _ = c.lua_checkstack(state, 6);
    const x: f32 = @floatCast(c.lua_tonumber(state, 1));
    const y: f32 = @floatCast(c.lua_tonumber(state, 2));
    const vx: f32 = @floatCast(c.lua_tonumber(state, 3));
    const vy: f32 = @floatCast(c.lua_tonumber(state, 4));
    const axis = c.lua_tostring(state, 5);
    const coordinate: f32 = @floatCast(c.lua_tonumber(state, 6));
    c.lua_pop(state, 6);

    const ival = if (axis[0] == 'x') x else y;
    // if(axis != "x" && axis != "y")
    // {
    // 	lua_pushstring(state, "invalid condition specified: choose either 'x' or 'y'");
    // 	lua_error(state);
    // }
    const left = ival < coordinate;

    // set up the world
    world.ball_position = .{ .x = x, .y = 600 - y };
    world.ball_velocity = .{ .x = vx, .y = -vy };

    var steps: i32 = 0;
    while (coordinate != ival and steps < 75 * 5) {
        steps += 1;
        // set ball valid to false to ignore blobby bounces
        world.step(.{}, .{}, false, true);
        // check for the condition
        const pos = world.ball_position;
        const v = if (axis[0] == 'x') pos.x else 600 - pos.y;
        if ((v < coordinate) != left)
            break;
    }
    // indicate failure
    if (steps == 75 * 5)
        steps = -1;

    c.lua_pushinteger(state, steps);
    var ret: c_int = 1;
    ret += lua_pushvector(state, world.ball_position, .position);
    ret += lua_pushvector(state, world.ball_velocity, .velocity);
    return ret;
}

pub fn getCachedMatchState(self: Self) DuelMatchState {
    return self.cached_state;
}

pub fn setCachedMatchState(self: *Self, state: DuelMatchState) void {
    self.cached_state = state;
}
