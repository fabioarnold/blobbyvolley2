pub const max_players = 2;

pub const PlayerSide = enum(u1) {
    left = 0,
    right = 1,
};

pub const blobby_height = 89;

pub const ground_plane_height_max = 500;
pub const ground_plane_height = ground_plane_height_max - blobby_height / 2;

pub const ball_radius = 31.5;
pub const ball_gravitation = 0.287;

pub const standard_ball_height = 269 + ball_radius;
pub const standard_ball_angular_velocity = 0.1;
