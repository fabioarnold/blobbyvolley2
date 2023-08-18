const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});
pub usingnamespace c;

pub fn lua_to_int(state: ?*c.lua_State, index: c_int) c_int {
    var value = c.lua_tonumber(state, index);
    value += if (value > 0) 0.5 else -0.5;
    return @intFromFloat(value);
}
