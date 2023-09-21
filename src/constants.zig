pub const max_players = 2;

pub const PlayerSide = enum(u1) {
    left = 0,
    right = 1,

    pub fn index(player_side: PlayerSide) usize {
        return @intFromEnum(player_side);
    }

    pub fn other(player_side: PlayerSide) PlayerSide {
        return switch (player_side) {
            .left => .right,
            .right => .left,
        };
    }
};
pub const player_none = -1;
pub const player_left = PlayerSide.left.index();
pub const player_right = PlayerSide.right.index();

// Border Settings
pub const left_plane = 0;
pub const right_plane = 800;

// Blobby Settings
pub const blobby_height = 89.0;
pub const blobby_upper_sphere = 19;
pub const blobby_upper_radius = 25;
pub const blobby_lower_sphere = 13;
pub const blobby_lower_radius = 33;

// Ground Settings
pub const ground_plane_height_max = 500;
pub const ground_plane_height = ground_plane_height_max - blobby_height / 2.0;

// This is exactly the half of the gravitation, I checked it in the original code
pub const blobby_max_jump_height = ground_plane_height - 206.375;	// ground_y - max_y
pub const blobby_jump_acceleration = -15.1;

// these values are calculated from the other two
pub const gravitation = blobby_jump_acceleration * blobby_jump_acceleration / blobby_max_jump_height;
pub const blobby_jump_buffer = gravitation / 2.0;

// Ball Settings
pub const ball_radius = 31.5;
pub const ball_gravitation = 0.287;
pub const ball_collision_velocity = @sqrt(0.75 * right_plane * ball_gravitation);

// Volley Ball Net
pub const net_position_x = right_plane / 2;
pub const net_position_y = 438;
pub const net_radius = 7;
pub const net_sphere_position = 284;

pub const standard_ball_height = 269 + ball_radius;

pub const blobby_speed = 4.5; // blobby_speed is necessary to determine the size of the input buffer
pub const standard_ball_angular_velocity = 0.1;
