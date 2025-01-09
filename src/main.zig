const std = @import("std");
const c = @cImport({
    @cInclude("mgba/gba/core.h");
});

pub fn main() !void {
    std.debug.print("Testing mGBA bindings...\n", .{});

    // I'm not yet sure if we will be using a GBA core or some other type,
    // but this suffices for now to test that we've built the bindings correctly.
    const core = c.GBACoreCreate();
    if (core == null) {
        return error.CoreCreateFailed;
    }

    std.debug.print("mGBA core initialized successfully\n", .{});
}
