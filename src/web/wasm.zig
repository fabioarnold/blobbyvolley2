const std = @import("std");
const logger = std.log.scoped(.wasm);

pub extern fn performanceNow() f32;

pub extern fn dateNow() f64;

pub extern fn download(filenamePtr: [*]const u8, filenameLen: usize, mimetypePtr: [*]const u8, mimetypeLen: usize, dataPtr: [*]const u8, dataLen: usize) void;

extern fn wasm_log_write(ptr: [*]const u8, len: usize) void;

extern fn wasm_log_flush() void;

const WriteError = error{};
const LogWriter = std.io.Writer(void, WriteError, writeLog);

fn writeLog(_: void, msg: []const u8) WriteError!usize {
    wasm_log_write(msg.ptr, msg.len);
    return msg.len;
}

/// Overwrite default log handler
pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = switch (message_level) {
        .err => "error",
        .warn => "warning",
        .info => "info",
        .debug => "debug",
    };
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    (LogWriter{ .context = {} }).print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;

    wasm_log_flush();
}

// Since we're using C libraries we have to use a global allocator.
pub var global_allocator: std.mem.Allocator = undefined;

const malloc_alignment = 16;

export fn malloc(size: usize) callconv(.C) ?*anyopaque {
    const buffer = global_allocator.alignedAlloc(u8, malloc_alignment, size + malloc_alignment) catch {
        logger.err("Allocation failure for size={}", .{size});
        return null;
    };
    std.mem.writeIntNative(usize, buffer[0..@sizeOf(usize)], buffer.len);
    return buffer.ptr + malloc_alignment;
}

export fn realloc(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
    const p = ptr orelse return malloc(size);
    defer free(p);
    if (size == 0) return null;
    const actual_buffer = @as([*]u8, @ptrCast(p)) - malloc_alignment;
    const len = std.mem.readIntNative(usize, actual_buffer[0..@sizeOf(usize)]);
    const new = malloc(size);
    return memmove(new, actual_buffer + malloc_alignment, len);
}

export fn free(ptr: ?*anyopaque) callconv(.C) void {
    const actual_buffer = @as([*]u8, @ptrCast(ptr orelse return)) - 16;
    const len = std.mem.readIntNative(usize, actual_buffer[0..@sizeOf(usize)]);
    global_allocator.free(actual_buffer[0..len]);
}

export fn memmove(dest: ?*anyopaque, src: ?*anyopaque, n: usize) ?*anyopaque {
    const csrc = @as([*]u8, @ptrCast(src))[0..n];
    const cdest = @as([*]u8, @ptrCast(dest))[0..n];

    // Create a temporary array to hold data of src
    var buf: [1 << 12]u8 = undefined;
    const temp = if (n <= buf.len) buf[0..n] else @as([*]u8, @ptrCast(malloc(n)))[0..n];
    defer if (n > buf.len) free(@as(*anyopaque, @ptrCast(temp)));

    for (csrc, 0..) |c, i|
        temp[i] = c;

    for (temp, 0..) |c, i|
        cdest[i] = c;

    return dest;
}

export fn memcpy(dst: ?[*]u8, src: ?[*]const u8, num: usize) ?[*]u8 {
    if (dst == null or src == null)
        @panic("Invalid usage of memcpy!");
    std.mem.copy(u8, dst.?[0..num], src.?[0..num]);
    return dst;
}

export fn memset(ptr: ?[*]u8, value: c_int, num: usize) ?[*]u8 {
    if (ptr == null)
        @panic("Invalid usage of memset!");
    // FIXME: the optimizer replaces this with a memset call which leads to a stack overflow.
    // std.mem.set(u8, ptr.?[0..num], @intCast(u8, value));
    for (ptr.?[0..num]) |*d|
        d.* = @as(u8, @intCast(value));
    return ptr;
}

export fn strlen(s: ?[*:0]const u8) usize {
    return std.mem.indexOfSentinel(u8, 0, s orelse return 0);
}

export fn strchr(s: ?[*:0]const u8, c: c_int) ?[*:0]const u8 {
    const str = s orelse return null;
    var i: usize = 0;
    while (true) : (i += 1) {
        if (str[i] == c) return str + i;
        if (str[i] == 0) break;
    }
    return null;
}

export fn strpbrk(s: ?[*:0]const u8, charset: ?[*:0]const u8) ?[*:0]const u8 {
    const str = s orelse return null;
    const cs = charset orelse return null;
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {
        var j: usize = 0;
        while (cs[j] != 0) : (j += 1) {
            if (str[i] == cs[j]) return str + i;
        }
    }
    return null;
}

export fn strcpy(dest: [*]u8, src: [*]const u8) ?[*]u8 {
    var i: usize = 0;
    while (src[i] != 0) : (i += 1) dest[i] = src[i];
    return dest;
}

export fn strncpy(dest: [*]u8, src: [*]const u8, n: usize) ?[*]u8 {
    var i: usize = 0;
    while (i < n and src[i] != 0) : (i += 1) dest[i] = src[i];
    while (i < n) : (i += 1) dest[i] = 0;
    return dest;
}

export fn strcmp(s1: [*:0]const u8, s2: [*:0]const u8) c_int {
    var i: usize = 0;
    while (s1[i] != 0 and s2[i] != 0) : (i += 1) {
        if (s1[i] < s2[i]) return -1;
        if (s1[i] > s2[i]) return 1;
    }
    if (s1[i] == s2[i]) return 0;
    if (s1[i] == 0) return -1;
    return 1;
}

export fn strncmp(s1: ?[*]const u8, s2: ?[*]const u8, n: usize) c_int {
    var i: usize = 0;
    while (s1.?[i] != 0 and s2.?[i] != 0 and i < n) : (i += 1) {
        if (s1.?[i] < s2.?[i]) return -1;
        if (s1.?[i] > s2.?[i]) return 1;
    }
    if (s1.?[i] == s2.?[i]) return 0;
    if (s1.?[i] == 0) return -1;
    return 1;
}

export fn strcoll(s1: [*: 0]const u8, s2: [*: 0]const u8) c_int {
    return strcmp(s1, s2);
}

export fn strtol(nptr: [*]const u8, endptr: *?[*]const u8, base: c_int) c_long {
    if (base != 10) unreachable; // not implemented
    var l: c_long = 0;
    var i: usize = 0;
    while (nptr[i] != 0) : (i += 1) {
        const c = nptr[i];
        if (c >= '0' and c <= '9') {
            l *= 10;
            l += c - '0';
        } else {
            break;
        }
    }
    endptr.* = @as([*]const u8, @ptrCast(&nptr[i]));
    return l;
}

export fn __assert_fail(a: i32, b: i32, c: i32, d: i32) void {
    _ = a;
    _ = b;
    _ = c;
    _ = d;
}

export fn abs(i: c_int) c_int {
    return if (i < 0) -i else i;
}

export fn pow(x: f64, y: f64) f64 {
    return std.math.pow(f64, x, y);
}

export fn ldexp(x: f64, n: c_int) f64 {
    return std.math.ldexp(x, n);
}

export fn asin(x: f64) f64 {
    return std.math.asin(x);
}

export fn acos(x: f64) f64 {
    return std.math.acos(x);
}

export fn atan2(y: f64, x: f64) f64 {
    return std.math.atan2(f64, y, x);
}

export var __stack_chk_guard: c_ulong = undefined;

export fn __stack_chk_guard_setup() void {
    __stack_chk_guard = 0xBAAAAAAD;
}

export fn __stack_chk_fail() void {
    @panic("stack fail");
}

export fn abort() void {
    @panic("abort");
}

export var errno: c_int = 0;

export fn strerror(errnum: c_int) ?[*:0]const u8 {
    _ = errnum;
    @panic("strerror");
}

pub const FILE = opaque {};

export var stdin: *FILE = undefined;
export var stdout: *FILE = undefined;
export var stderr: *FILE = undefined;

export fn fflush(stream: *FILE) c_int {
    _ = stream;
    @panic("fflush");
}

export fn fopen(noalias filename: [*:0]const u8, noalias modes: [*:0]const u8) ?*FILE {
    _ = filename;
    _ = modes;
    @panic("fopen");
}

export fn freopen(noalias filename: [*:0]const u8, noalias modes: [*:0]const u8, stream: ?*FILE) ?*FILE {
    _ = filename;
    _ = modes;
    _ = stream;
    @panic("freopen");
}

export fn fclose(stream: *FILE) c_int {
    _ = stream;
    @panic("fclose");
}

export fn feof(stream: *FILE) c_int {
    _ = stream;
    @panic("feof");
}

export fn ferror(stream: *FILE) c_int {
    _ = stream;
    @panic("ferror");
}

export fn fwrite(noalias ptr: [*]const u8, size_of_type: usize, item_count: usize, noalias stream: *FILE) usize {
    _ = ptr;
    _ = size_of_type;
    _ = item_count;
    _ = stream;
    @panic("fwrite");
}

export fn fread(noalias ptr: [*]u8, size_of_type: usize, item_count: usize, noalias stream: *FILE) usize {
    _ = ptr;
    _ = size_of_type;
    _ = item_count;
    _ = stream;
    @panic("fread");
}

export fn getc(stream: *FILE) c_int {
    _ = stream;
    @panic("getc");
}

export fn fprintf(stream: *FILE, format: ?[*:0]const u8, ...) c_int {
    _ = stream;
    _ = format;
    @panic("fprintf");
}

export fn frexp(value: f64, exp: ?*c_int) f64 {
    const r = std.math.frexp(value);
    if (exp) |e| e.* = r.exponent;
    return r.significand;
}

const lconv = struct {
    decimal_point: *c_char = @constCast(@ptrCast(".")),
    thousands_sep: *c_char = @constCast(@ptrCast("")),
    grouping: *c_char = @constCast(@ptrCast("")),
    int_curr_symbol: *c_char = @constCast(@ptrCast("")),
    currency_symbol: *c_char = @constCast(@ptrCast("")),
    mon_decimal_point: *c_char = @constCast(@ptrCast("")),
    mon_thousands_sep: *c_char = @constCast(@ptrCast("")),
    mon_grouping: *c_char = @constCast(@ptrCast("")),
    positive_sign: *c_char = @constCast(@ptrCast("")),
    negative_sign: *c_char = @constCast(@ptrCast("")),
    int_frac_digits: c_char = -1,
    frac_digits: c_char = -1,
    p_cs_precedes: c_char = -1,
    p_sep_by_space: c_char = -1,
    n_cs_precedes: c_char = -1,
    n_sep_by_space: c_char = -1,
    p_sign_posn: c_char = -1,
    n_sign_posn: c_char = -1,
    int_p_cs_precedes: c_char = -1,
    int_n_cs_precedes: c_char = -1,
    int_p_sep_by_space: c_char = -1,
    int_n_sep_by_space: c_char = -1,
    int_p_sign_posn: c_char = -1,
    int_n_sign_posn: c_char = -1,
};
var s_lconv = lconv{};
export fn localeconv() *lconv {
    return &s_lconv;
}

export fn snprintf(str: [*:0]const u8, size: usize, format: [*:0]const u8, ...) c_int {
    _ = str;
    _ = size;
    _ = format;
    @panic("snprintf");
}

// The strspn() function spans the initial part of the null-terminated string s as long as the characters from s occur in the null-terminated string charset.  In other words, it computes the string array index of the first character of s which is
// not in charset, else the index of the first null character.
export fn strspn(str: [*:0]const u8, charset: [*:0]const u8) usize {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {
        var j: usize = 0;
        while (charset[j] != 0) : (j += 1) {
            if (str[i] == charset[j]) break;
        }
        if (charset[j] == 0) break;
    }
    return i;
}

export fn strtod(nptr: [*c]const u8, endptr: [*c][*c]u8) f64 {
    var d: f64 = 0;
    var i: usize = 0;
    while (nptr[i] != 0) : (i += 1) {
        const c = nptr[i];
        if (c >= '0' and c <= '9') {
            d *= 10;
            d += @floatFromInt(c - '0');
        } else if (c == '.') {
            // ok
        } else if (c == 'e' or c == 'E') {
            // ok
        } else if (c == '+' or c == '-') {
            // ok
        } else {
            break;
        }
    }
    endptr[0] = @constCast(@ptrCast(&nptr[i]));
    return d;
}

const time_t = usize;
export fn time(tloc: *time_t) time_t {
    _ = tloc;
    return @intFromFloat(@round(dateNow() / 1000.0));
}

var rand_state: c_uint = 0;
export fn rand() c_int {
    rand_state *%= 1664525;
    rand_state +%= 1013904223;
    return @bitCast(rand_state);
}

export fn srand(seed: c_uint) void {
    rand_state = seed;
}

export fn isalnum(c: c_int) c_int {
    return @intFromBool((c >= '0' and c <= '9') or (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z'));
}

export fn isdigit(c: c_int) c_int {
    return @intFromBool(c >= '0' and c <= '9');
}

export fn toupper(c: c_int) c_int {
    if (c >= 'a' and c <= 'z') return c - ('a' - 'A');
    return c;
}
