const c = @import("c.zig");
const constants = @import("constants.zig");

const Self = @This();

state: *c.lua_State,

pub fn init(self: *Self) void {
    self.state = c.luaL_newstate().?;

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

pub fn setGameFunctions(self: Self) void {
    _ = self;
    // c.lua_register(self.state, "get_ball_pos", get_ball_pos);
    // c.lua_register(self.state, "get_ball_vel", get_ball_vel);
    // c.lua_register(self.state, "get_blob_pos", get_blob_pos);
    // c.lua_register(self.state, "get_blob_vel", get_blob_vel);
    // c.lua_register(self.state, "get_score", get_score);
    // c.lua_register(self.state, "get_touches", get_touches);
    // c.lua_register(self.state, "is_ball_valid", get_ball_valid);
    // c.lua_register(self.state, "is_game_running", get_game_running);
    // c.lua_register(self.state, "get_serving_player", get_serving_player);
    // c.lua_register(self.state, "simulate", simulate_steps);
    // c.lua_register(self.state, "simulate_until", simulate_until);
}

fn setLuaGlobal(self: Self, name: []const u8, value: f64) void {
    c.lua_pushnumber(self.state, value);
    c.lua_setglobal(self.state, name.ptr);
}

// inline const DuelMatchState getMatchState( lua_State* state )  {
// 	auto sc = getScriptComponent( state );
// 	return sc->getMatchState();
// }
// inline PhysicWorld* getWorld( lua_State* s )  { return IScriptableComponent::Access::getWorld(s); }

// // standard lua functions
// int get_ball_pos(lua_State* state)
// {
// 	return lua_pushvector(state, getMatchState(state).getBallPosition(), VectorType::POSITION);
// }

// int get_ball_vel(lua_State* state)
// {
// 	return lua_pushvector(state, getMatchState(state).getBallVelocity(), VectorType::VELOCITY);
// }

// int get_blob_pos(lua_State* state)
// {
// 	const auto& s = getMatchState(state);
// 	auto side = (PlayerSide) lua_to_int( state, -1 );
// 	lua_pop(state, 1);
// 	assert( side == LEFT_PLAYER || side == RIGHT_PLAYER );
// 	return lua_pushvector(state, s.getBlobPosition(side), VectorType::POSITION);
// }

// int get_blob_vel(lua_State* state)
// {
// 	const auto& s = getMatchState(state);
// 	PlayerSide side = (PlayerSide) lua_to_int( state, -1 );
// 	lua_pop(state, 1);
// 	assert( side == LEFT_PLAYER || side == RIGHT_PLAYER );
// 	return lua_pushvector(state, s.getBlobVelocity(side), VectorType::VELOCITY);
// }

// int get_score( lua_State* state )
// {
// 	const auto& s = getMatchState(state);
// 	PlayerSide side = (PlayerSide) lua_to_int( state, -1 );
// 	lua_pop(state, 1);
// 	assert( side == LEFT_PLAYER || side == RIGHT_PLAYER );
// 	lua_pushinteger(state, s.getScore(side));
// 	return 1;
// }

// int get_touches( lua_State* state )
// {
// 	const auto& s = getMatchState(state);
// 	PlayerSide side = (PlayerSide) lua_to_int( state, -1 );
// 	lua_pop(state, 1);
// 	assert( side == LEFT_PLAYER || side == RIGHT_PLAYER );
// 	lua_pushinteger(state, s.getHitcount(side));
// 	return 1;
// }

// int get_ball_valid( lua_State* state )
// {
// 	const auto& s = getMatchState(state);
// 	lua_pushboolean(state, !s.getBallDown());
// 	return 1;
// }

// int get_game_running( lua_State* state )
// {
// 	const auto& s = getMatchState(state);
// 	lua_pushboolean(state, s.getBallActive());
// 	return 1;
// }

// int get_serving_player( lua_State* state )
// {
// 	const auto& s = getMatchState(state);
// 	lua_pushinteger(state, s.getServingPlayer());
// 	return 1;
// }

// int simulate_steps( lua_State* state )
// {
// 	/// \todo should we gather and return all events that happen to the ball on the way?
// 	PhysicWorld* world = getWorld( state );
// 	// get the initial ball settings
// 	lua_checkstack(state, 5);
// 	int steps = lua_tointeger( state, 1);
// 	float x = lua_tonumber( state, 2);
// 	float y = lua_tonumber( state, 3);
// 	float vx = lua_tonumber( state, 4);
// 	float vy = lua_tonumber( state, 5);
// 	lua_pop( state, 5);

// 	world->setBallPosition( Vector2{x, 600 - y} );
// 	world->setBallVelocity( Vector2{vx, -vy});
// 	for(int i = 0; i < steps; ++i)
// 	{
// 		// set ball valid to false to ignore blobby bounces
// 		world->step(PlayerInput(), PlayerInput(), false, true);
// 	}

// 	int ret = lua_pushvector(state, world->getBallPosition(), VectorType::POSITION);
// 	ret += lua_pushvector(state, world->getBallVelocity(), VectorType::VELOCITY);
// 	return ret;
// }

// int simulate_until(lua_State* state)
// {
// 	/// \todo should we gather and return all events that happen to the ball on the way?
// 	PhysicWorld* world = getWorld( state );
// 	// get the initial ball settings
// 	lua_checkstack(state, 6);
// 	float x = lua_tonumber( state, 1);
// 	float y = lua_tonumber( state, 2);
// 	float vx = lua_tonumber( state, 3);
// 	float vy = lua_tonumber( state, 4);
// 	std::string axis = lua_tostring( state, 5 );
// 	const float coordinate = lua_tonumber( state, 6 );
// 	lua_pop( state, 6 );

// 	const float ival = axis == "x" ? x : y;
// 	if(axis != "x" && axis != "y")
// 	{
// 		lua_pushstring(state, "invalid condition specified: choose either 'x' or 'y'");
// 		lua_error(state);
// 	}
// 	const bool init = ival < coordinate;

// 	// set up the world
// 	world->setBallPosition( Vector2{x, 600 - y} );
// 	world->setBallVelocity( Vector2{vx, -vy});

// 	int steps = 0;
// 	while(coordinate != ival && steps < 75 * 5)
// 	{
// 		steps++;
// 		// set ball valid to false to ignore blobby bounces
// 		world->step(PlayerInput(), PlayerInput(), false, true);
// 		// check for the condition
// 		auto pos = world->getBallPosition();
// 		float v = axis == "x" ? pos.x : 600 - pos.y;
// 		if( (v < coordinate) != init )
// 			break;
// 	}
// 	// indicate failure
// 	if(steps == 75 * 5)
// 		steps = -1;

// 	lua_pushinteger(state, steps);
// 	int ret = 1;
// 	ret += lua_pushvector(state, world->getBallPosition(), VectorType::POSITION);
// 	ret += lua_pushvector(state, world->getBallVelocity(), VectorType::VELOCITY);
// 	return ret;
// }