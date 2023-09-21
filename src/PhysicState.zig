const std = @import("std");
const constants = @import("constants.zig");
const Vec2 = @import("Vec2.zig");

const Self = @This();

blob_position: [constants.max_players]Vec2,
blob_velocity: [constants.max_players]Vec2,
blob_state: [constants.max_players]f32,

ball_position: Vec2,
ball_velocity: Vec2,
ball_rotation: f32,
ball_angular_velocity: f32,

pub fn swapSides(self: *Self) void {
    self.blob_position[constants.player_left].x = constants.right_plane - self.blob_position[constants.player_left].x;
    self.blob_position[constants.player_right].x = constants.right_plane - self.blob_position[constants.player_right].x;
    self.blob_velocity[constants.player_left].x = -self.blob_velocity[constants.player_left].x;
    self.blob_velocity[constants.player_right].x = -self.blob_velocity[constants.player_right].x;
    std.mem.swap(Vec2, &self.blob_position[constants.player_left], &self.blob_position[constants.player_right]);
    std.mem.swap(Vec2, &self.blob_velocity[constants.player_left], &self.blob_velocity[constants.player_right]);
    std.mem.swap(f32, &self.blob_state[constants.player_left], &self.blob_state[constants.player_right]);

    self.ball_position.x = constants.right_plane - self.ball_position.x;
    self.ball_velocity.x = -self.ball_velocity.x;
    self.ball_angular_velocity = -self.ball_angular_velocity;
    self.ball_rotation = 2.0 * std.math.pi - self.ball_rotation;
}
