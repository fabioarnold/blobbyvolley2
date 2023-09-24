const LocalInputSource = @import("LocalInputSource.zig");
const ScriptedInputSource = @import("ScriptedInputSource.zig");
const PlayerInput = @import("PlayerInput.zig");
const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
const DuelMatch = @import("DuelMatch.zig");

pub const InputSourceType = enum {
    local,
    scripted,
};

const Self = InputSource;

pub const InputSource = union(InputSourceType) {
    local: LocalInputSource,
    scripted: ScriptedInputSource,

    pub fn initLocal(self: *Self) void {
        self.* = .{ .local = .{} };
    }

    pub fn initScripted(self: *Self, script: []const u8, side: PlayerSide, difficulty: i32, match: *DuelMatch) void {
        self.* = .{ .scripted = undefined };
        self.scripted.init(script, side, difficulty, match);
    }

    pub fn getNextInput(self: *Self) PlayerInput {
        return switch (self.*) {
            .local => self.local.getNextInput(),
            .scripted => self.scripted.getNextInput(),
        };
    }
};
