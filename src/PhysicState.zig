const constants = @import("constants.zig");
const Vec2 = @import("Vec2.zig");

blob_position: [constants.max_players]Vec2,
blob_velocity: [constants.max_players]Vec2,
blob_state: [constants.max_players]f32,

ball_position: Vec2,
ball_velocity: Vec2,
ball_rotation: f32,
ball_angular_velocity: f32,