const std = @import("std");
const duration = @import("./duration.zig");
const mem = std.mem;

const usage =
    \\nap [-h] <duration>
    \\
    \\ sleep alternative that supports sub-second durations and prints time remaining periodically
    \\
    \\ -h, --help      print this help message and exit
    \\ <duration>      duration to sleep for, in the format of 1h2m3s4ms5us6ns
    \\
    \\ examples:
    \\   nap 1h2m3s4ms5us6ns
    \\   nap -h
;

pub fn main() !void {
    const argv = std.os.argv;

    if (argv.len == 1) {
        std.debug.print("missing duration\n", .{});
        std.debug.print("{s}\n", .{usage});
        return;
    }

    const arg = mem.sliceTo(argv[1], 0);

    var dt = try duration.durationParse(arg);

    while (dt > 0) {
        std.debug.print("{any} left\n", .{
            std.fmt.fmtDuration(dt),
        });

        const to_sleep = std.math.min(10 * std.time.ns_per_s, dt);
        std.time.sleep(to_sleep);

        dt = std.math.max(0, dt - to_sleep);
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
