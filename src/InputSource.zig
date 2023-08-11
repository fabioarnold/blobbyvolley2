const PlayerInput = @import("PlayerInput.zig");
const keys = @import("web/keys.zig");

const Self = @This();

left_key: u32 = keys.KEY_LEFT,
right_key: u32 = keys.KEY_RIGHT,
up_key: u32 = keys.KEY_UP,

pub fn updateInput(self: Self) PlayerInput {
    return .{
        .left = keys.isKeyDown(self.left_key),
        .right = keys.isKeyDown(self.right_key),
        .up = keys.isKeyDown(self.up_key),
    };
}