const std = @import("std");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
});


const game_logic = @import("game_logic.zig");

pub fn createWindowAndRenderer(title: [*:0]const u8, width: c_int, height: c_int) !struct { *c.SDL_Window, *c.SDL_Renderer } {
    var window: ?*c.SDL_Window = null;
    var renderer: ?*c.SDL_Renderer = null;
    try errify(c.SDL_CreateWindowAndRenderer(title, width, height, 0, &window, &renderer));
    return .{ window.?, renderer.? };
}

pub fn loadSpritesTexture(renderer: *c.SDL_Renderer, bmp_data: []const u8) !*c.SDL_Texture {
    const stream: *c.SDL_IOStream = try errify(c.SDL_IOFromConstMem(bmp_data, bmp_data.len));
    const surface: *c.SDL_Surface = try errify(c.SDL_LoadBMP_IO(stream, true));
    defer c.SDL_DestroySurface(surface);
    const texture: *c.SDL_Texture = try errify(c.SDL_CreateTextureFromSurface(renderer, surface));
    return texture;
}

pub fn renderObject(renderer: *c.SDL_Renderer, texture: *c.SDL_Texture, src: *const c.SDL_FRect, dst: game_logic.Box) !void {
    try errify(c.SDL_RenderTexture(renderer, texture, src, &.{
        .x = dst.x,
        .y = dst.y,
        .w = dst.w,
        .h = dst.h,
    }));
}

pub fn mainLoop(window: *c.SDL_Window, renderer: *c.SDL_Renderer, sprites_texture: *c.SDL_Texture) !void {
    var timekeeper: game_logic.Timekeeper = .{ .tocks_per_s = c.SDL_GetPerformanceFrequency() };

    while (true) {
        // Process SDL events
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => return,
                else => {},
            }
        }

        // Update game state
        game_logic.updateGameState(&timekeeper);

        // Draw
        try errify(c.SDL_SetRenderDrawColor(renderer, 0x47, 0x5b, 0x8d, 0xff));
        try errify(c.SDL_RenderClear(renderer));

        // Example rendering of paddle and ball
        const paddle_box = game_logic.Box{ .x = 100, .y = 100, .w = 50, .h = 10 };
        const ball_box = game_logic.Box{ .x = 150, .y = 150, .w = 10, .h = 10 };

        try renderObject(renderer, sprites_texture, &sprites.paddle, paddle_box);
        try renderObject(renderer, sprites_texture, &sprites.ball, ball_box);

        try errify(c.SDL_RenderPresent(renderer));
        timekeeper.produce(c.SDL_GetPerformanceCounter());
    }
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
