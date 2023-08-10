const Self = @This();

x: f32,
y: f32,

pub fn length(self: Self) f32 {
    return @sqrt(self.x * self.x + self.y * self.y);
}