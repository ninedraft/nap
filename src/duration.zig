const std = @import("std");
const eql = std.mem.eql;
const parseInt = std.fmt.parseInt;
const ComptimeStringMap = std.ComptimeStringMap;
const testing = std.testing;
const time = std.time;
const math = std.math;

pub const Duration = u64;

pub const DurationParseError = error{
    InvalidFormat,
    MissingUnit,
    Overflow,
};

fn okDuration(x: u64) DurationParseError!u64 {
    return x;
}

test "durationParse" {
    try testing.expectEqual(okDuration(0), durationParse("0"));

    inline for (unitMap.kvs) |test_case| {
        const unit = test_case.value;
        const unit_str = test_case.key;
        try testing.expectEqual(okDuration(unit), durationParse("1" ++ unit_str));
    }

    try testing.expectEqual(okDuration(time.ns_per_hour + 1), durationParse("1h1ns"));
}

pub fn durationParse(buf: []const u8) DurationParseError!Duration {
    var d: Duration = 0;
    var str = buf[0..];

    if (str.len == 0) {
        return DurationParseError.InvalidFormat;
    }

    if (eql(u8, str, "0")) {
        return 0;
    }

    while (str.len != 0) {
        var v: u64 = 0;
        var f: u64 = 0;
        var scale: f64 = 0.0;

        const ch = str[0];
        // The next character must be [0-9.]
        if ((ch < '0' or ch > '9') and ch != '.') {
            return DurationParseError.InvalidFormat;
        }

        const head = leadingInt(str) catch return DurationParseError.InvalidFormat;
        const pre = head.rest.len != str.len; // whether we consumed anything before a period
        str = head.rest;
        v = head.x;

        var post = false;
        if (str.len > 0 and str[0] == '.') {
            str = str[1..];
            var fraction = try leadingFraction(str);
            post = str.len != fraction.rest.len;
            str = fraction.rest;
            scale = fraction.scale;
            f = fraction.x;
        }

        if (!pre and !post) {
            // no digits (e.g. ".s" or "-.s")
            return DurationParseError.InvalidFormat;
        }

        // Consume unit.
        var i: usize = 0;

        for (str) |ci| {
            if (ci == '.' or ('0' <= ci and ci <= '9')) {
                break;
            }
            i += 1;
        }

        if (i == 0) {
            return DurationParseError.MissingUnit;
        }

        const u = str[0..i];
        str = str[i..];

        const unit = unitMap.get(u) orelse return DurationParseError.MissingUnit;

        v *= unit;

        if (f > 0) {
            // float64 is needed to be nanosecond accurate for fractions of hours.
            // v >= 0 && (f*unit/scale) <= 3.6e+12 (ns/h, h is the largest unit)
            const cast = math.lossyCast;
            const scaled = cast(f64, f) * cast(f64, unit) / scale;
            v += cast(u64, scaled);
        }

        d += v;
    }

    return d;
}

const ScannedLeadingInt = struct {
    x: u64,
    rest: []const u8,
};

fn leadingInt(buf: []const u8) !ScannedLeadingInt {
    var i: usize = 0;
    for (buf) |ch| {
        if (ch < '0' or ch > '9') {
            break;
        }
        i += 1;
    }

    if (i == 0) {
        return ScannedLeadingInt{ .x = 0, .rest = buf };
    }

    const x = try parseInt(u64, buf[0..i], 10);

    return ScannedLeadingInt{ .x = x, .rest = buf[i..] };
}

const ScannedLeadingFraction = struct {
    x: u64,
    scale: f64,
    rest: []const u8,
};

fn leadingFraction(buf: []const u8) !ScannedLeadingFraction {
    var i: usize = 0;
    var scale: f64 = 1;
    var overflow = false;
    var x: u64 = 0;

    for (buf) |ch| {
        if (ch < '0' or ch > '9') {
            break;
        }
        if (overflow) {
            continue;
        }

        if (x > (1 << 63 - 1) / 10) {
            // It's possible for overflow to give a positive number, so take care.
            overflow = true;
            continue;
        }

        var y = 10 * x + @as(u64, ch) - 0;
        x = y;
        scale *= 10;
        i += 1;
    }

    return ScannedLeadingFraction{ .x = x, .scale = scale, .rest = buf[i..] };
}

const unitMap = ComptimeStringMap(u64, .{
    .{ "ns", 1 },
    .{ "us", time.ns_per_us },
    .{ "µs", time.ns_per_us }, // U+00B5 = micro symbol
    .{ "μs", time.ns_per_us }, // U+03BC = Greek letter mu
    .{ "ms", time.ns_per_ms },
    .{ "s", time.ns_per_s },
    .{ "m", time.ns_per_min },
    .{ "h", time.ns_per_hour },
});
