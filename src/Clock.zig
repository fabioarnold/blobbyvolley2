const wasm = @import("web/wasm.zig");

const Self = @This();

running: bool,
last_time: f64,
game_time: f64,

pub fn init(self: *Self) void {
    self.running = false;
    self.last_time = 0;
    self.game_time = 0;
}

pub fn start(self: *Self) void {
    self.last_time = wasm.dateNow();
    self.running = true;
}

pub fn stop(self: *Self) void {
    self.running = false;
}

pub fn isRunning(self: *Self) bool {
    return self.running;
}

pub fn step(self: *Self) void {
    if (self.running) {
        const new_time = wasm.dateNow();
        self.game_time += new_time - self.last_time;
        self.last_time = new_time;
    }
}
