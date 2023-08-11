const PlayerInput = @import("PlayerInput.zig");

const Self = @This();

pub fn updateInput(self: Self) PlayerInput {
    _ = self;
    return .{
        .left = false,
        .right = false,
        .up = false,
    };
}