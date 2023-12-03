const std = @import("std");

const ReadErr = error{ FileOpenErr, ReadErr, StatFileErr };

fn read_file(allocator: std.mem.Allocator, path: []const u8) ReadErr![]u8 {
    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();

    var file = std.fs.cwd().openFile(path, .{}) catch return error.FileOpenErr;
    defer file.close();

    const file_stat = std.fs.cwd().statFile(path) catch return error.StatFileErr;
    const buffer = allocator.alloc(u8, file_stat.size) catch return error.ReadErr;

    _ = file.readAll(buffer) catch return error.ReadErr;

    return buffer;
}

fn stringToInt(T: anytype, str: []const u8) T {
    var r: T = 0;
    var i: usize = str.len;

    while (i > 0) : (i -= 1) {
        const pow: u64 = (std.math.pow(u64, 10, str.len - i));

        if (pow == 0) {
            r += str[i - 1] - 0x30;
        } else {
            r += (pow * (str[i - 1] - 0x30));
        }
    }

    return r;
}

fn process_round(round: []const u8) [3]u64 {
    const colors = [_]u8{ 0, 2, 1 };
    const cubes = std.mem.trim(u8, round, " ");
    var results = std.mem.splitSequence(u8, cubes, ",");

    var r = [3]u64{ 0, 0, 0 };

    while (results.next()) |result| {
        const stripped_result = std.mem.trim(u8, result, " ");

        const space_idx = std.mem.indexOf(u8, stripped_result, " ") orelse unreachable;
        const color = std.mem.trim(u8, stripped_result[space_idx..], " ");
        std.log.info("'{s}' {d}", .{ stripped_result, space_idx });
        const color_idx = colors[color.len - 3];

        const val: u64 = stringToInt(u64, stripped_result[0..space_idx]);
        r[color_idx] = val;
    }

    return r;
}

fn process_scores(scores: []const u8) bool {
    const max_nums = [3]u64{ 12, 13, 14 };
    var rounds = std.mem.splitSequence(u8, scores, ";");

    while (rounds.next()) |round| {
        const r = process_round(round);

        std.log.info("S: {d} {d} {d}", .{ r[0], r[1], r[2] });

        if (r[0] > max_nums[0] or r[1] > max_nums[1] or r[2] > max_nums[2]) return false;
    }

    return true;
}

fn process_powers(scores: []const u8) [3]u64 {
    var min_rgb: [3]u64 = [3]u64{ 0, 0, 0 };
    var rounds = std.mem.splitSequence(u8, scores, ";");

    while (rounds.next()) |round| {
        const r = process_round(round);

        if (r[0] > min_rgb[0]) min_rgb[0] = r[0];
        if (r[1] > min_rgb[1]) min_rgb[1] = r[1];
        if (r[2] > min_rgb[2]) min_rgb[2] = r[2];
    }

    std.log.info("P: {d} {d} {d}", .{ min_rgb[0], min_rgb[1], min_rgb[2] });

    return min_rgb;
}

fn process_game(game: []const u8) struct { u64, u64, bool } {
    const colon_idx = std.mem.indexOf(u8, game, ":") orelse unreachable;
    const game_number_slice = game[5..colon_idx];

    const game_number: u64 = stringToInt(u64, game_number_slice);
    const is_valid_game = process_scores(game[colon_idx + 1 ..]);
    const powers = process_powers(game[colon_idx + 1 ..]);
    const power = powers[0] * powers[1] * powers[2];

    std.log.info("Game IDX '{d}' ({d}): valid={}", .{ game_number, power, is_valid_game });

    return .{ game_number, power, is_valid_game };
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var alloc = gpa.allocator();

    const text = read_file(alloc, "./input") catch |err| switch (err) {
        error.FileOpenErr => {
            std.log.err("Unable to open file", .{});
            return;
        },

        error.StatFileErr => {
            std.log.err("Unable to get file size", .{});
            return;
        },

        error.ReadErr => {
            std.log.err("Unable to read file", .{});
            return;
        },
    };
    defer alloc.free(text);

    var games = std.mem.splitSequence(u8, text, "\n");

    // std.debug.print("{s}\n", .{text});
    var game_sum: u64 = 0;
    var game_power: u64 = 0;

    while (games.next()) |game| {
        const scores = process_game(game);

        if (scores.@"2") {
            game_sum += scores.@"0";
        }

        game_power += scores.@"1";
    }

    std.debug.print("Sum is {d}: Power is {d}\n", .{ game_sum, game_power });

    return;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
