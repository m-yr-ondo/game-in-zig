const std = @import("std");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
});

const graphics = @import("graphics.zig");
const game_logic = @import("game_logic.zig");

pub fn main() !void {
    try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMEPAD));
    defer c.SDL_Quit();

    const window_w = 640;
    const window_h = 480;

    const window_and_renderer = try graphics.createWindowAndRenderer("Speedbreaker", window_w, window_h);
    defer c.SDL_DestroyRenderer(window_and_renderer[1]);
    defer c.SDL_DestroyWindow(window_and_renderer[0]);

    const sprites_texture = try graphics.loadSpritesTexture(window_and_renderer[1], sprites.bmp);
    defer c.SDL_DestroyTexture(sprites_texture);

    try graphics.mainLoop(window_and_renderer[0], window_and_renderer[1], sprites_texture);
}

inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}
