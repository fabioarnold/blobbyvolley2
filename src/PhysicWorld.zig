const constants = @import("constants.zig");
const Vec2 = @import("Vec2.zig");

const Self = @This();

ball_position: Vec2,
ball_velocity: Vec2,
ball_rotation: f32,
ball_angular_velocity: f32,

blob_position: [constants.max_players]Vec2,

pub fn reset(self: *Self) void {
    self.ball_position = .{ .x = 200, .y = constants.standard_ball_height };
    self.ball_rotation = 0;
    self.ball_angular_velocity = constants.standard_ball_angular_velocity;

    self.blob_position[0] = .{ .x = 200, .y = constants.ground_plane_height };
    self.blob_position[1] = .{ .x = 600, .y = constants.ground_plane_height };
}

pub fn update(self: *Self, dt: f32) void {
    _ = dt;
    self.ball_rotation += self.ball_angular_velocity;
}