const std = @import("std");
const DuelMatch = @import("../DuelMatch.zig");
const Renderer = @import("../Renderer.zig");
const imgui = @import("../imgui.zig");
const InputSource = @import("../input.zig").InputSource;
const keys = @import("../web/keys.zig");
const config = @import("../config.zig");

const Self = @This();

match: DuelMatch,
winner: bool,

pub fn init(self: *Self, allocator: std.mem.Allocator) void {
    self.* = .{
        .match = undefined,
        .winner = false,
    };
    self.match.init(allocator, false);

    self.match.setInputSources();
}

pub fn step(self: *Self) void {
    if (self.match.paused) {
        // gui pause
    } else if (self.winner) {
        imgui.label("Winner!", 400, 270, .{ .horizontal = .center });
    } else {
        self.match.step();
        if (self.match.logic.winning_player) |_| {
            self.winner = true;
        }
    }

    self.presentGameUI();
}

var left_score_buf: [8]u8 = undefined;
var right_score_buf: [8]u8 = undefined;
var time_buf: [16]u8 = undefined;

fn presentGameUI(self: *Self) void {
    // Scores
    const left_serve: u8 = if (self.match.logic.serving_player == .left) '!' else ' ';
    const right_serve: u8 = if (self.match.logic.serving_player == .right) '!' else ' ';
    const left_score = std.fmt.bufPrint(&left_score_buf, "{d:0>2}{c}", .{ self.match.logic.scores[0], left_serve }) catch unreachable;
    const right_score = std.fmt.bufPrint(&right_score_buf, "{d:0>2}{c}", .{ self.match.logic.scores[1], right_serve }) catch unreachable;
    imgui.label(left_score, 24, 24, .{ .vertical = .top });
    imgui.label(right_score, 800 - 24, 24, .{ .horizontal = .right, .vertical = .top });

    // blob name / time textfields
    // imgui.doText(GEN_ID, Vector2(12, 550), mMatch->getPlayer(LEFT_PLAYER).getName());
    // imgui.doText(GEN_ID, Vector2(788, 550), mMatch->getPlayer(RIGHT_PLAYER).getName(), TF_ALIGN_RIGHT);
    const seconds: usize = @intFromFloat(self.match.logic.clock.game_time * 0.001);
    const time_txt = std.fmt.bufPrint(&time_buf, "{d:0>2}:{d:0>2}", .{ seconds / 60, seconds % 60 }) catch unreachable;
    imgui.label(time_txt, 400, 24, .{ .horizontal = .center, .vertical = .top });
}
