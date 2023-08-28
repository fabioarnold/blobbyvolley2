const Self = @This();

x: f32,
y: f32,

pub fn add(self: *Self, v: Self) void {
    self.x += v.x;
    self.y += v.y;
}

pub fn subtract(self: *Self, v: Self) void {
    self.x -= v.x;
    self.y -= v.y;
}

pub fn scale(self: *Self, sx: f32, sy: f32) void {
    self.x *= sx;
    self.y *= sy;
}

pub fn scaleScalar(self: *Self, s: f32) void {
    self.scale(s, s);
}

pub fn dot(self: Self, v: Self) f32 {
    return self.x * v.x + self.y * v.y;
}

pub fn lengthSquared(self: Self) f32 {
    return self.dot(self);
}

pub fn length(self: Self) f32 {
    return @sqrt(self.lengthSquared());
}

pub fn normalize(self: *Self) void {
    const len = self.length();
    if (len > 0) {
        self.scaleScalar(1.0 / len);
    }
}

pub fn reflect(self: *Self, normal: Self) void {
    var r = normal;
    r.scaleScalar(2 * self.dot(normal));
    self.x -= r.x;
    self.y -= r.y;
}
