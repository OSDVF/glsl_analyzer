const std = @import("std");

pub const NAME = "glsl_analyzer";

pub const Arguments = struct {
    allow_reinit: bool = false,
    version: bool = false,
    channel: ChannelKind = .stdio,
    scheme: []const u8 = "file://",
    client_pid: ?c_int = null,
    dev_mode: ?[]const u8 = null,
    parse_file: ?[]const u8 = null,
    print_ast: bool = false,

    pub const ChannelKind = union(enum) {
        stdio: void,
        socket: u16,
        ws: u16,
    };

    const usage =
        "Usage: " ++ NAME ++
        \\ [OPTIONS]
        \\
        \\LSP:
        \\     --clientProcessId <PID>  PID of the client process (used by LSP client).
        \\
        \\Options:
        \\ -h, --help               Print this message.
        \\     --stdio              Communicate over stdio. [default]
        \\ -p, --port <PORT>        Communicate over socket.
        \\ -ws,--websocket <PORT>   Communicate over WebSocket.
        \\ -s, --scheme <SCHEME>    Scheme to use for file URL parsing (default file://).
        \\ -r, --allow-reinit       Allow reinitialization of the server. [default: false]
        \\     --dev-mode <PATH>    Enable development mode: redirects stderr to the given path.
        \\     --parse-file <PATH>  Parses the given file, prints diagnostics, then exits.
        \\     --print-ast          Prints the parse tree. Only valid with --parse-file.
        \\
        \\
    ;

    fn printHelp() noreturn {
        std.io.getStdOut().writer().writeAll(usage) catch {};
        std.process.exit(1);
    }

    fn printVersion() noreturn {
        std.io.getStdOut().writer().writeAll(@import("build_options").version) catch {};
        std.process.exit(0);
    }

    fn fail(comptime fmt: []const u8, args: anytype) noreturn {
        std.io.getStdErr().writer().writeAll(usage) catch {};
        std.log.err(fmt ++ "\n", args);
        std.process.exit(1);
    }

    const ValueParser = struct {
        args: *std.process.ArgIterator,
        option: []const u8,
        value: ?[]const u8,

        pub fn get(self: *@This(), name: []const u8) []const u8 {
            if (self.value) |value| return value;
            if (self.args.next()) |value| return value;
            fail("'{s}' expects an argument '{s}'", .{ self.option, name });
        }
    };

    pub fn parse(allocator: std.mem.Allocator) !Arguments {
        var args = try std.process.argsWithAllocator(allocator);
        defer args.deinit();
        _ = args.skip();

        var parsed = Arguments{};

        while (args.next()) |arg| {
            const option_end = std.mem.indexOfScalar(u8, arg, '=') orelse arg.len;
            const option = arg[0..option_end];

            var value_parser = ValueParser{
                .args = &args,
                .option = option,
                .value = if (option_end == arg.len) null else arg[option_end + 1 ..],
            };

            if (isAny(option, &.{ "--help", "-h" })) {
                printHelp();
            }

            if (isAny(option, &.{ "--version", "-v" })) {
                printVersion();
            }

            if (isAny(option, &.{"--stdio"})) {
                parsed.channel = .stdio;
                continue;
            }

            if (isAny(option, &.{"--dev-mode"})) {
                const path = value_parser.get("PATH");
                parsed.dev_mode = path;
                continue;
            }

            if (isAny(option, &.{ "--port", "-p" })) {
                const value = value_parser.get("PORT");
                const port = std.fmt.parseInt(u16, value, 10) catch
                    fail("{s}: not a valid port number: {s}", .{ option, value });
                parsed.channel = .{ .socket = port };
                continue;
            }

            if (isAny(option, &.{ "--websocket", "-ws" })) {
                const value = value_parser.get("PORT");
                const port = std.fmt.parseInt(u16, value, 10) catch
                    fail("{s}: not a valid port number: {s}", .{ option, value });
                parsed.channel = .{ .ws = port };
                continue;
            }

            if (isAny(option, &.{ "--scheme", "-s" })) {
                parsed.scheme = value_parser.get("SCHEME");
                continue;
            }

            if (isAny(option, &.{ "--allow-reinit", "-r" })) {
                parsed.allow_reinit = true;
                continue;
            }

            if (isAny(option, &.{"--clientProcessId"})) {
                const value = value_parser.get("PID");
                parsed.client_pid = std.fmt.parseInt(c_int, value, 10) catch
                    fail("{s}: not a valid PID: {s}", .{ option, value });
                continue;
            }

            if (isAny(option, &.{"--parse-file"})) {
                parsed.parse_file = value_parser.get("PATH");
                continue;
            }

            if (isAny(option, &.{"--print-ast"})) {
                parsed.print_ast = true;
                continue;
            }

            fail("unexpected argument '{s}'", .{arg});
        }

        return parsed;
    }

    fn isAny(name: []const u8, expected: []const []const u8) bool {
        for (expected) |string| {
            if (std.mem.eql(u8, name, string)) return true;
        } else {
            return false;
        }
    }
};
