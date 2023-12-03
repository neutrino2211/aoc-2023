const std = @import("std");

const ReadErr = error{ FileOpenErr, ReadErr, StatFileErr };

const PossiblePartNumber = struct {
    index: usize,
    line: usize,
    value: []u8,
    value_num: u64,
};

const GridItemType = enum {
    period,
    star,
    symbol,
    part_number,
};

const GridItem = struct {
    item_type: GridItemType,
    value: u8,
    line: usize,
    index: usize,
};

const StarMap = std.AutoHashMap(struct { usize, usize }, std.ArrayList(PossiblePartNumber));
var gears: StarMap = StarMap.init(std.heap.page_allocator);

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

fn gridItemsToString(items: []GridItem) std.ArrayList(u8) {
    var list = std.ArrayList(u8).init(std.heap.page_allocator);

    for (items) |item| {
        list.append(item.value) catch unreachable;
    }

    return list;
}

fn span_has_symbol(span: []GridItem, part_number: PossiblePartNumber) bool {
    var r: bool = false;
    for (span) |item| {
        switch (item.item_type) {
            .symbol => r = true,
            .star => {
                r = true;
                if (gears.getPtr(.{ item.line, item.index })) |list| {
                    list.*.append(part_number) catch unreachable;
                } else {
                    var list = std.ArrayList(PossiblePartNumber).init(std.heap.page_allocator);
                    list.append(part_number) catch unreachable;
                    gears.put(.{ item.line, item.index }, list) catch unreachable;
                }
            },
            else => {},
        }
    }

    return r;
}

fn item_is_adjacent(item: PossiblePartNumber, curr_line: []GridItem, prev_line: ?[]GridItem, next_line: ?[]GridItem) bool {
    var r: bool = false;

    const start_idx = @max(0, item.index - 1);
    var end_idx = @min(curr_line.len - 1, item.index + item.value.len + 1);

    if (prev_line) |l| {
        end_idx = @min(l.len - 1, item.index + item.value.len + 1);
        const str = gridItemsToString(l[start_idx..end_idx]);
        defer str.deinit();

        std.log.info("item: {}, slice: {s}", .{ item, str.items });
        if (span_has_symbol(l[start_idx..end_idx], item)) {
            r = true;
        }
    }

    const curr_str = gridItemsToString(curr_line[start_idx..end_idx]);
    defer curr_str.deinit();

    std.log.info("item: {}, slice: {s}", .{ item, curr_str.items });
    if (span_has_symbol(curr_line[start_idx..end_idx], item)) {
        r = true;
    }

    if (next_line) |l| {
        end_idx = @min(l.len - 1, item.index + item.value.len + 1);
        const str = gridItemsToString(l[start_idx..end_idx]);
        defer str.deinit();

        std.log.info("item: {}, slice: {s}", .{ item, str.items });
        if (span_has_symbol(l[start_idx..end_idx], item)) {
            r = true;
        }
    }

    return r;
}

fn process_grid_line(line_idx: usize, curr_line: []GridItem, prev_line: ?[]GridItem, next_line: ?[]GridItem) u64 {
    var i: u64 = 0;
    var sum: u64 = 0;

    var tmp_num = std.ArrayList(u8).init(std.heap.page_allocator);
    defer tmp_num.deinit();

    while (i < curr_line.len) : (i += 1) {
        switch (curr_line[i].item_type) {
            .part_number => {
                tmp_num.append(curr_line[i].value) catch unreachable;
            },

            else => {
                if (tmp_num.items.len > 0) {
                    if (item_is_adjacent(.{ .index = i - tmp_num.items.len, .line = line_idx, .value = tmp_num.items, .value_num = stringToInt(u64, tmp_num.items) }, curr_line, prev_line, next_line)) {
                        sum += stringToInt(u64, tmp_num.items);
                    }

                    std.log.info("num: {s}", .{tmp_num.items});

                    tmp_num.shrinkAndFree(0);
                }
            },
        }
    }

    return sum;
}

fn process_grid(grid: []std.ArrayList(GridItem)) u64 {
    var sum: u64 = 0;

    for (grid, 0..) |grid_line, i| {
        std.log.info("i: {d}, l: {d}, il :{d}", .{ i, grid.len, grid_line.items.len });
        var prev_line: ?[]GridItem = null;
        var next_line: ?[]GridItem = null;

        if (i == 0) {
            next_line = grid[i + 1].items;
        } else if (i == grid.len - 1) {
            prev_line = grid[i - 1].items;
        } else {
            prev_line = grid[i + 1].items;
            next_line = grid[i - 1].items;
        }

        sum += process_grid_line(i, grid_line.items, prev_line, next_line);
    }

    return sum;
}

fn process_line(alloc: std.mem.Allocator, line: []const u8, line_idx: usize) std.ArrayList(GridItem) {
    var grid_line = std.ArrayList(GridItem).init(alloc);

    var tmp_num = std.ArrayList(u8).init(alloc);
    defer tmp_num.deinit();

    for (line, 0..) |char, i| {
        switch (char) {
            0x30...0x39 => {
                grid_line.append(.{ .item_type = .part_number, .value = char, .index = i, .line = line_idx }) catch unreachable;
            },

            '.' => {
                grid_line.append(.{ .item_type = .period, .value = char, .index = i, .line = line_idx }) catch unreachable;
            },

            '*' => {
                grid_line.append(.{ .item_type = .star, .value = char, .index = i, .line = line_idx }) catch unreachable;
            },

            else => {
                grid_line.append(.{ .item_type = .symbol, .value = char, .index = i, .line = line_idx }) catch unreachable;
            },
        }
    }

    return grid_line;
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const text = read_file(alloc, "./input") catch |err| switch (err) {
        error.FileOpenErr => {
            std.log.err("Unable to open the file", .{});
            return;
        },

        error.StatFileErr => {
            std.log.err("Unable to stat the file", .{});
            return;
        },

        error.ReadErr => {
            std.log.err("Unable to read file", .{});
            return;
        },
    };
    defer alloc.free(text);

    var grid = std.ArrayList(std.ArrayList(GridItem)).init(alloc);
    defer grid.deinit();

    var iter = std.mem.splitSequence(u8, text, "\n");

    var line_idx: usize = 0;

    while (iter.next()) |line| {
        const new_line = std.fmt.allocPrint(alloc, ".{s}.", .{line}) catch unreachable;
        defer alloc.free(new_line);

        const grid_line = process_line(alloc, new_line, line_idx);

        grid.append(grid_line) catch unreachable;

        line_idx += 1;
    }

    const sum = process_grid(grid.items);

    for (grid.items) |item| {
        item.deinit();
    }

    var power: u64 = 0;
    var gears_iter = gears.keyIterator();

    std.log.info("gears: {}", .{gears.count()});

    while (gears_iter.next()) |gear| {
        const list = gears.getPtr(gear.*);
        if (list) |l| {
            if (l.*.items.len == 2) {
                std.log.info("star: {d},{d} 0: {d}, 1: {d}", .{ gear.*.@"0", gear.*.@"1", l.*.items[0].value_num, l.*.items[1].value_num });
                power += (l.*.items[0].value_num * l.*.items[1].value_num);
            }
        }
    }

    std.log.info("grid length: {d}, sum: {d}, power: {d}", .{ grid.items.len, sum, power });
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
