const std = @import("std");

const ReadErr = error{ FileOpenErr, ReadErr, StatFileErr };

fn has_match(chars: []const u8) u8 {
    const numbers = [_][]const u8{ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };

    var i: u8 = 1;

    for (numbers) |num| {
        if (std.mem.endsWith(u8, chars, num)) {
            return i;
        }

        i += 1;
    }

    return 0;
}

fn get_line_numbers(allocator: std.mem.Allocator, line: []const u8) [2]u8 {
    var numbers = std.ArrayList(u8).init(allocator);
    defer numbers.deinit();

    var speculativeChars = std.ArrayList(u8).init(allocator);
    defer speculativeChars.deinit();

    var numbers_len: u8 = 0;
    var i: u8 = 0;

    for (line) |char| {
        speculativeChars.append(char) catch continue;

        if (char > 0x2F and char < 0x3A) {
            numbers.append(char - 0x30) catch continue;
            numbers_len += 1;
            speculativeChars.shrinkAndFree(0);
        } else {
            const m = has_match(speculativeChars.items);

            if (m > 0) {
                numbers.append(m) catch continue;
                numbers_len += 1;
            }
        }

        i += 1;
    }

    if (numbers_len == 1) {
        const n = numbers.pop();
        return [2]u8{ n, n };
    }

    return [2]u8{ numbers.items[0], numbers.items[numbers_len - 1] };
}

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

fn run_on_file(allocator: std.mem.Allocator, path: []const u8) u64 {
    const text = read_file(allocator, path) catch |err| switch (err) {
        error.FileOpenErr => {
            std.log.err("Unable to open file", .{});
            return 0;
        },
        error.ReadErr => {
            std.log.err("Unable to read file", .{});
            return 0;
        },
        error.StatFileErr => {
            std.log.err("Unable to get the file size", .{});
            return 0;
        },
    };
    defer allocator.free(text);

    var sum: u64 = 0;

    var iter = std.mem.splitSequence(u8, text, "\n");

    while (iter.next()) |line| {
        const numbers = get_line_numbers(allocator, line);
        const num = (numbers[0] * 10) + numbers[1];

        std.log.info("{d} ({d}) \t| {s}", .{ line.len, num, line });

        sum += num;
    }

    return sum;
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.log.info("Starting...", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const sum = run_on_file(alloc, "./input-1");

    std.log.info("sum: {d}", .{sum});
}

test "First Star" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const sum = run_on_file(alloc, "./input-test");
    const expectedSum: u64 = 142;

    try std.testing.expect(expectedSum == sum);
}

test "Second Star" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const sum = run_on_file(alloc, "./input-test-2");
    const expectedSum: u64 = 281;

    try std.testing.expect(expectedSum == sum);
}
