const Self = @This();

left: bool = false,
right: bool = false,
up: bool = false,

pub fn swapSides(self: *Self) void {
    const tmp = self.left;
    self.left = self.right;
    self.right = tmp;
}
