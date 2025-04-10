const std = @import("std");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
});

// Import graphics module
const graphics = @import("graphics.zig");

pub const Box = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    fn intersects(a: Box, b: Box) bool {
        const min_x = b.x - a.w;
        const max_x = b.x + b.w;
        if (a.x > min_x and a.x < max_x) {
            const min_y = b.y - a.h;
            const max_y = b.y + b.h;
            if (a.y > min_y and a.y < max_y) {
                return true;
            }
        }
        return false;
    }

    fn sweepTest(a: Box, a_vel_x: f32, a_vel_y: f32, b: Box, b_vel_x: f32, b_vel_y: f32) ?Collision {
        const vel_x_inv = 1 / (a_vel_x - b_vel_x);
        const vel_y_inv = 1 / (a_vel_y - b_vel_y);
        const min_x = b.x - a.w;
        const min_y = b.y - a.h;
        const max_x = b.x + b.w;
        const max_y = b.y + b.h;
        const t_min_x = (min_x - a.x) * vel_x_inv;
        const t_min_y = (min_y - a.y) * vel_y_inv;
        const t_max_x = (max_x - a.x) * vel_x_inv;
        const t_max_y = (max_y - a.y) * vel_y_inv;
        const entry_x = @min(t_min_x, t_max_x);
        const entry_y = @min(t_min_y, t_max_y);
        const exit_x = @max(t_min_x, t_max_x);
        const exit_y = @max(t_min_y, t_max_y);
        const last_entry = @max(entry_x, entry_y);
        const first_exit = @min(exit_x, exit_y);
        if (last_entry < first_exit and last_entry < 1 and first_exit > 0) {
            var sign_x: f32 = 0;
            var sign_y: f32 = 0;
            sign_x -= @floatFromInt(@intFromBool(last_entry == t_min_x));
            sign_x += @floatFromInt(@intFromBool(last_entry == t_max_x));
            sign_y -= @floatFromInt(@intFromBool(last_entry == t_min_y));
            sign_y += @floatFromInt(@intFromBool(last_entry == t_max_y));
            return .{ .t = last_entry, .sign_x = sign_x, .sign_y = sign_y };
        }
        return null;
    }

    const Collision = struct {
        t: f32,
        sign_x: f32,
        sign_y: f32,
    };
};

pub const Paddle = struct {
    box: Box,
    src_rect: *const c.SDL_FRect,
};

pub const Ball = struct {
    box: Box,
    vel_x: f32,
    vel_y: f32,
    launched: bool,
    src_rect: *const c.SDL_FRect,

    fn getPaddleBounceAngle(ball: Ball, paddle: Paddle) f32 {
        const min_x = paddle.box.x - ball.box.w;
        const max_x = paddle.box.x + paddle.box.w;
        const min_angle = std.math.degreesToRadians(195);
        const max_angle = std.math.degreesToRadians(345);
        const angle = ((ball.box.x - min_x) / (max_x - min_x)) * (max_angle - min_angle) + min_angle;
        return std.math.clamp(angle, min_angle, max_angle);
    }
};

pub const Brick = struct {
    box: Box,
    src_rect: *const c.SDL_FRect,
};

pub const PhysicalControllerState = struct {
    k_left: bool = false,
    k_right: bool = false,
    k_lshift: bool = false,
    k_space: bool = false,
    k_r: bool = false,
    k_escape: bool = false,
    m_left: bool = false,
    m_xrel: f32 = 0,
    g_left: bool = false,
    g_right: bool = false,
    g_left_shoulder: bool = false,
    g_right_shoulder: bool = false,
    g_south: bool = false,
    g_east: bool = false,
    g_back: bool = false,
    g_start: bool = false,
    g_leftx: i16 = 0,
    g_left_trigger: i16 = 0,
    g_right_trigger: i16 = 0,
};

pub const VirtualControllerState = struct {
    move_paddle_left: bool = false,
    move_paddle_right: bool = false,
    slow_paddle_movement: bool = false,
    launch_ball: bool = false,
    reset_game: bool = false,
    lock_mouse: bool = false,
    move_paddle_exact: f32 = 0,
};

pub const Timekeeper = struct {
    const updates_per_s = 60;
    const max_accumulated_updates = 8;
    const snap_frame_rates = .{ updates_per_s, 30, 120, 144 };
    const ticks_per_tock = 720; // Least common multiple of 'snap_frame_rates'
    const snap_tolerance_us = 200;
    const us_per_s = 1_000_000;
    tocks_per_s: u64,
    accumulated_ticks: u64 = 0,
    previous_timestamp: ?u64 = null,

    fn consume(timekeeper: *Timekeeper) bool {
        const ticks_per_s: u64 = timekeeper.tocks_per_s * ticks_per_tock;
        const ticks_per_update: u64 = @divExact(ticks_per_s, updates_per_s);
        if (timekeeper.accumulated_ticks >= ticks_per_update) {
            timekeeper.accumulated_ticks -= ticks_per_update;
            return true;
        } else {
            return false;
        }
    }

    fn produce(timekeeper: *Timekeeper, current_timestamp: u64) void {
        if (timekeeper.previous_timestamp) |previous_timestamp| {
            const ticks_per_s: u64 = timekeeper.tocks_per_s * ticks_per_tock;
            const elapsed_ticks: u64 = (current_timestamp -% previous_timestamp) *| ticks_per_tock;
            const snapped_elapsed_ticks: u64 = inline for (snap_frame_rates) |snap_frame_rate| {
                const target_ticks: u64 = @divExact(ticks_per_s, snap_frame_rate);
                const abs_diff = @max(elapsed_ticks, target_ticks) - @min(elapsed_ticks, target_ticks);
                if (abs_diff *| us_per_s <= snap_tolerance_us *| ticks_per_s) {
                    break target_ticks;
                }
            } else elapsed_ticks;
            const ticks_per_update: u64 = @divExact(ticks_per_s, updates_per_s);
            const max_accumulated_ticks: u64 = max_accumulated_updates * ticks_per_update;
            timekeeper.accumulated_ticks = @min(timekeeper.accumulated_ticks +| snapped_elapsed_ticks, max_accumulated_ticks);
        }
        timekeeper.previous_timestamp = current_timestamp;
    }
};

pub fn resetGame() void {
    // Reset game logic here
}

pub fn updateGameState(timekeeper: *Timekeeper) void {
    // Update game state logic here
}

pub fn getScore() u32 {
    // Return current score
    return 0;
}
