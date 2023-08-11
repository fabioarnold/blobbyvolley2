const std = @import("std");
const constants = @import("constants.zig");
const PlayerSide = constants.PlayerSide;
const Vec2 = @import("Vec2.zig");
const PlayerInput = @import("PlayerInput.zig");
const PhysicState = @import("PhysicState.zig");

const Self = @This();

blob_position: [constants.max_players]Vec2,
blob_velocity: [constants.max_players]Vec2,
blob_state: [constants.max_players]f32,
current_blobby_animation_speed: [constants.max_players]f32,

ball_position: Vec2,
ball_velocity: Vec2,
ball_rotation: f32 = 0,
ball_angular_velocity: f32 = constants.standard_ball_angular_velocity,

pub fn init(self: *Self) void {
    self.blob_position[0] = .{ .x = 200, .y = constants.ground_plane_height };
    self.blob_position[1] = .{ .x = 600, .y = constants.ground_plane_height };
    self.blob_state[0] = 0;
    self.blob_state[1] = 0;

    self.ball_position = .{ .x = 200, .y = constants.standard_ball_height };
    self.ball_rotation = 0;
    self.ball_angular_velocity = constants.standard_ball_angular_velocity;
}

pub fn step(self: *Self, left_input: PlayerInput, right_input: PlayerInput, is_ball_valid: bool, is_game_running: bool) void {
    self.handleBlob(.left, left_input);
    self.handleBlob(.right, right_input);

    if (is_game_running) {
        // move ball ds = a/2 * dt^2 + v * dt
        self.ball_position.x += self.ball_velocity.x;
        self.ball_position.y += self.ball_velocity.y;
        self.ball_position.y += 0.5 * constants.ball_gravitation;
        self.ball_velocity.y += constants.ball_gravitation;
    }

    if (is_ball_valid) {
        _ = self.handleBlobbyBallCollision(.left);
        _ = self.handleBlobbyBallCollision(.right);
    }

    self.handleBallWorldCollisions();

    // Collision between blobby and the net
    const max_x = constants.net_position_x - constants.net_radius - constants.blobby_lower_radius;
    if (self.blob_position[0].x > max_x)
        self.blob_position[0].x = max_x;

    const min_x = constants.net_position_x + constants.net_radius + constants.blobby_lower_radius;
    if (self.blob_position[1].x < min_x)
        self.blob_position[1].x = min_x;

    // Collision between blobby and the border
    if (self.blob_position[0].x < constants.left_plane)
        self.blob_position[0].x = constants.left_plane;

    if (self.blob_position[1].x > constants.right_plane)
        self.blob_position[1].x = constants.right_plane;

    // Velocity Integration
    if (!is_game_running) {
        self.ball_rotation += self.ball_angular_velocity;
    } else if (self.ball_velocity.x > 0) {
        self.ball_rotation += self.ball_angular_velocity * self.ball_velocity.length() / 6.0;
    } else {
        self.ball_rotation -= self.ball_angular_velocity * self.ball_velocity.length() / 6.0;
    }

    // Overflow-Protection
    const two_pi = 2.0 * std.math.pi;
    if (self.ball_rotation < 0) {
        self.ball_rotation += two_pi;
    } else if (self.ball_rotation > two_pi) {
        self.ball_rotation -= two_pi;
    }
}

pub fn getState(self: Self) PhysicState {
    return .{
        .blob_position = self.blob_position,
        .blob_velocity = self.blob_velocity,
        .blob_state = self.blob_state,

        .ball_position = self.ball_position,
        .ball_velocity = self.ball_velocity,
        .ball_rotation = self.ball_rotation,
        .ball_angular_velocity = self.ball_angular_velocity,
    };
}

const blobby_animation_speed = 0.5;

fn blobbyStartAnimation(self: *Self, player: PlayerSide) void {
    if (self.current_blobby_animation_speed[player.index()] == 0) {
        self.current_blobby_animation_speed[player.index()] = blobby_animation_speed;
    }
}

fn blobbyAnimationStep(self: *Self, player: PlayerSide) void {
    const player_index = player.index();
    if (self.blob_state[player_index] < 0) {
        self.current_blobby_animation_speed[player_index] = 0;
        self.blob_state[player_index] = 0;
    }

    if (self.blob_state[player_index] >= 4.5) {
        self.current_blobby_animation_speed[player_index] = -blobby_animation_speed;
    }

    self.blob_state[player_index] += self.current_blobby_animation_speed[player_index];

    if (self.blob_state[player_index] >= 5) {
        self.blob_state[player_index] = 4.99;
    }
}

fn handleBlob(self: *Self, player: PlayerSide, input: PlayerInput) void {
    const player_index = player.index();

    var cur_gravity: f32 = constants.gravitation;

    if (input.up) {
        if (self.blobHitGround(player)) {
            self.blob_velocity[player_index].y = constants.blobby_jump_acceleration;
            self.blobbyStartAnimation(player);
        }

        cur_gravity -= constants.blobby_jump_buffer;
    }

    if ((input.left or input.right) and self.blobHitGround(player)) {
        self.blobbyStartAnimation(player);
    }

    if (input.right)
        self.blob_velocity[player_index].x += constants.blobby_speed;
    if (input.left)
        self.blob_velocity[player_index].x -= constants.blobby_speed;

    // compute blobby fall movement (dt = 1)
    // ds = a/2 * dt^2 + v * dt
    self.blob_position[player_index].x += self.blob_velocity[player_index].x;
    self.blob_position[player_index].y += self.blob_velocity[player_index].y;
    self.blob_position[player_index].y += 0.5 * cur_gravity;
    // dv = a * dt
    self.blob_velocity[player_index].y += cur_gravity;

    // Hitting the ground
    if (self.blob_position[player_index].y > constants.ground_plane_height) {
        if (self.blob_velocity[player_index].y > 3.5) {
            self.blobbyStartAnimation(player);
        }

        self.blob_position[player_index].y = constants.ground_plane_height;
        self.blob_velocity[player_index].y = 0.0;
    }

    self.blobbyAnimationStep(player);
}

fn handleBlobbyBallCollision(self: *Self, player: PlayerSide) bool {
    var collision_center = self.blob_position[player.index()];
    // check for impact
    if (self.playerBottomBallCollision(player)) {
        collision_center.y += constants.blobby_lower_sphere;
    } else if (self.playerTopBallCollision(player)) {
        collision_center.y -= constants.blobby_upper_sphere;
    } else { // no impact!
        return false;
    }

    // ok, if we get here, there actually was a collision

    // calculate hit intensity
    // const intensity = @min(1.f, Vector2(self.ball_velocity, mBlobVelocity[player_index]).length() / 25.0);

    // set ball velocity
    self.ball_velocity.x = self.ball_position.x - collision_center.x;
    self.ball_velocity.y = self.ball_position.y - collision_center.y;
    self.ball_velocity.normalize();
    self.ball_velocity.scaleScalar(constants.ball_collision_velocity);
    self.ball_position.x += self.ball_velocity.x;
    self.ball_position.y += self.ball_velocity.y;

    // mCallback( MatchEvent{MatchEvent::BALL_HIT_BLOB, player, intensity} );

    return true;
}

fn handleBallWorldCollisions(self: *Self) void {
    // Ball to ground Collision
    if (self.ball_position.y + constants.ball_radius > constants.ground_plane_height_max) {
        self.ball_velocity.y = -self.ball_velocity.y;
        self.ball_velocity.scaleScalar(0.95);
        self.ball_position.y = constants.ground_plane_height_max - constants.ball_radius;
        // mCallback( MatchEvent{MatchEvent::BALL_HIT_GROUND, self.ball_position.x > NET_POSITION_X ? RIGHT_PLAYER : LEFT_PLAYER, 0} );
    }

    // Border Collision
    if (self.ball_position.x - constants.ball_radius <= constants.left_plane and self.ball_velocity.x < 0) {
        self.ball_velocity.x = -self.ball_velocity.x;
        // set the ball's position
        self.ball_position.x = constants.left_plane + constants.ball_radius;
        // mCallback( MatchEvent{MatchEvent::BALL_HIT_WALL, LEFT_PLAYER, 0} );
    } else if (self.ball_position.x + constants.ball_radius >= constants.right_plane and self.ball_velocity.x > 0) {
        self.ball_velocity.x = -self.ball_velocity.x;
        // set the ball's position
        self.ball_position.x = constants.right_plane - constants.ball_radius;
        // mCallback( MatchEvent{MatchEvent::BALL_HIT_WALL, RIGHT_PLAYER, 0} );
    } else if (self.ball_position.y > constants.net_sphere_position and
        @fabs(self.ball_position.x - constants.net_position_x) < constants.ball_radius + constants.net_radius)
    {
        self.ball_velocity.x = -self.ball_velocity.x;
        // set the ball's position so that it touches the net
        if (self.ball_position.x > constants.net_position_x) {
            self.ball_position.x = constants.net_position_x + constants.ball_radius + constants.net_radius;
        } else {
            self.ball_position.x = constants.net_position_x - constants.ball_radius - constants.net_radius;
        }

        // mCallback( MatchEvent{MatchEvent::BALL_HIT_NET, right ? RIGHT_PLAYER : LEFT_PLAYER, 0} );
    } else {
        // Net Collisions
        const net_position = .{ .x = constants.net_position_x, .y = constants.net_sphere_position };
        if (circleCircleCollision(self.ball_position, constants.ball_radius, net_position, constants.net_radius)) {
            // calculate
            var normal = Vec2{
                .x = net_position.x - self.ball_position.x,
                .y = net_position.y - self.ball_position.y,
            };
            normal.normalize();

            // normal component of kinetic energy
            var perp_ekin = normal.dot(self.ball_velocity);
            perp_ekin *= perp_ekin;
            // parallel component of kinetic energy
            var para_ekin = self.ball_velocity.lengthSquared() - perp_ekin;

            // the normal component is damped stronger than the parallel component
            // the values are ~ 0.85 and ca. 0.95, because speed is sqrt(ekin)
            perp_ekin *= 0.7;
            para_ekin *= 0.9;

            const new_speed = @sqrt(perp_ekin + para_ekin);

            self.ball_velocity.reflect(normal);
            self.ball_velocity.normalize();
            self.ball_velocity.scaleScalar(new_speed);

            // pushes the ball out of the net
            self.ball_position = net_position;
            self.ball_position.x -= normal.x * (constants.net_radius + constants.ball_radius);
            self.ball_position.y -= normal.y * (constants.net_radius + constants.ball_radius);

            // mCallback( MatchEvent{MatchEvent::BALL_HIT_NET_TOP, NO_PLAYER, 0} );
        }
    }
}

fn blobHitGround(self: Self, player: PlayerSide) bool {
    return self.blob_position[player.index()].y >= constants.ground_plane_height;
}

fn playerTopBallCollision(self: Self, player: PlayerSide) bool {
    return circleCircleCollision(
        .{
            .x = self.blob_position[player.index()].x,
            .y = self.blob_position[player.index()].y - constants.blobby_upper_sphere,
        },
        constants.blobby_upper_radius,
        self.ball_position,
        constants.ball_radius,
    );
}

fn playerBottomBallCollision(self: Self, player: PlayerSide) bool {
    return circleCircleCollision(
        .{
            .x = self.blob_position[player.index()].x,
            .y = self.blob_position[player.index()].y - constants.blobby_lower_sphere,
        },
        constants.blobby_lower_radius,
        self.ball_position,
        constants.ball_radius,
    );
}

fn circleCircleCollision(p0: Vec2, r0: f32, p1: Vec2, r1: f32) bool {
    const distance = Vec2{ .x = p1.x - p0.x, .y = p1.y - p0.y };
    const r = r0 + r1;
    return distance.lengthSquared() < r * r;
}
