const std = @import("std");

const common_src = [_][]const u8{
    "src/base64.cpp",
    "src/BlobbyDebug.cpp",
    "src/Clock.cpp",
    "src/DuelMatch.cpp",
    "src/FileRead.cpp",
    "src/FileSystem.cpp",
    "src/FileWrite.cpp",
    "src/File.cpp",
    "src/GameLogic.cpp",
    "src/GenericIO.cpp",
    "src/Color.cpp",
    "src/NetworkMessage.cpp",
    "src/PhysicWorld.cpp",
    "src/SpeedController.cpp",
    "src/UserConfig.cpp",
    "src/PhysicState.cpp",
    "src/DuelMatchState.cpp",
    "src/GameLogicState.cpp",
    "src/InputSource.cpp",
    "src/PlayerInput.cpp",
    "src/IScriptableComponent.cpp",
    "src/PlayerIdentity.cpp",
    "src/server/DedicatedServer.cpp",
    "src/server/NetworkPlayer.cpp",
    "src/server/NetworkGame.cpp",
    "src/server/MatchMaker.cpp",
    "src/replays/ReplayRecorder.cpp",
    "src/replays/ReplaySavePoint.cpp",
};

const raknet_src = [_][]const u8{
    "src/raknet/BitStream.cpp",
    "src/raknet/GetTime.cpp",
    "src/raknet/InternalPacketPool.cpp",
    "src/raknet/NetworkTypes.cpp",
    "src/raknet/PacketPool.cpp",
    "src/raknet/RakClient.cpp",
    "src/raknet/RakNetStatistics.cpp",
    "src/raknet/RakPeer.cpp",
    "src/raknet/RakServer.cpp",
    "src/raknet/ReliabilityLayer.cpp",
    "src/raknet/SimpleMutex.cpp",
    "src/raknet/SocketLayer.cpp",
};

const blobnet_src = [_][]const u8{
    "src/blobnet/layer/Http.cpp",
};

const blobby_src = [_][]const u8{
    "src/Blood.cpp",
    "src/TextManager.cpp",
    "src/IMGUI.cpp",
    "src/InputManager.cpp",
    "src/LocalInputSource.cpp",
    "src/RenderManager.cpp",
    "src/RenderManagerGL2D.cpp",
    "src/RenderManagerSDL.cpp",
    "src/RenderManagerNull.cpp",
    "src/ScriptedInputSource.cpp",
    "src/SoundManager.cpp",
    "src/replays/ReplayPlayer.cpp",
    "src/replays/ReplayLoader.cpp",
    "src/state/State.cpp",
    "src/state/GameState.cpp",
    "src/state/LocalGameState.cpp",
    "src/state/NetworkState.cpp",
    "src/state/OptionsState.cpp",
    "src/state/NetworkSearchState.cpp",
    "src/state/ReplayState.cpp",
    "src/state/ReplaySelectionState.cpp",
    "src/state/LobbyStates.cpp",
    "src/input_device/JoystickInput.cpp",
    "src/input_device/JoystickPool.cpp",
    "src/input_device/KeyboardInput.cpp",
    "src/input_device/MouseInput.cpp",
    "src/input_device/TouchInput.cpp",
    "src/BlobbyApp.cpp",
};

const lua_src = [_][]const u8{
    "deps/lua/lapi.c",
    "deps/lua/lauxlib.c",
    "deps/lua/lbaselib.c",
    "deps/lua/lbitlib.c",
    "deps/lua/lcode.c",
    "deps/lua/lcorolib.c",
    "deps/lua/lctype.c",
    "deps/lua/ldblib.c",
    "deps/lua/ldebug.c",
    "deps/lua/ldo.c",
    "deps/lua/ldump.c",
    "deps/lua/lfunc.c",
    "deps/lua/lgc.c",
    "deps/lua/linit.c",
    "deps/lua/liolib.c",
    "deps/lua/llex.c",
    "deps/lua/lmathlib.c",
    "deps/lua/lmem.c",
    "deps/lua/loadlib.c",
    "deps/lua/lobject.c",
    "deps/lua/lopcodes.c",
    "deps/lua/lparser.c",
    "deps/lua/lstate.c",
    "deps/lua/lstring.c",
    "deps/lua/lstrlib.c",
    "deps/lua/ltable.c",
    "deps/lua/ltablib.c",
    "deps/lua/ltm.c",
    "deps/lua/lundump.c",
    "deps/lua/lutf8lib.c",
    "deps/lua/lvm.c",
    "deps/lua/lzio.c",
};

pub fn build(b: *std.build.Builder) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const cpp_flags = [_][]const u8{ "-std=c++11", "-DTARGET_OS_IPHONE=0", "-DTARGET_OS_SIMULATOR=0" };
    const c_flags = [_][]const u8{};

    const tinyxml = b.addStaticLibrary(.{
        .name = "tinyxml",
        .target = target,
        .optimize = optimize,
    });
    tinyxml.addIncludePath(.{ .path = "deps/tinyxml" });
    tinyxml.addCSourceFile(.{ .file = .{ .path = "deps/tinyxml/tinyxml2.cpp" }, .flags = &cpp_flags });
    tinyxml.linkLibCpp();

    const lua = b.addStaticLibrary(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
    });
    lua.addCSourceFiles(&lua_src, &c_flags);

    const blobby = b.addExecutable(.{
        .name = "blobby",
        .target = target,
        .optimize = optimize,
    });
    blobby.addIncludePath(.{ .path = "src" });
    blobby.addIncludePath(.{ .path = "src/blobnet" });
    blobby.addIncludePath(.{ .path = "deps/tinyxml" });
    blobby.addIncludePath(.{ .path = "deps/lua" });
    blobby.addCSourceFiles(&common_src, &cpp_flags);
    blobby.addCSourceFiles(&raknet_src, &cpp_flags);
    blobby.addCSourceFiles(&blobnet_src, &cpp_flags);
    blobby.addCSourceFiles(&blobby_src, &cpp_flags);
    blobby.addCSourceFile(.{ .file = .{ .path = "src/main.cpp" }, .flags = &cpp_flags });
    blobby.linkLibrary(tinyxml);
    blobby.linkLibrary(lua);
    blobby.linkSystemLibrary("SDL2");
    blobby.linkSystemLibrary("physfs");
    if (target.isDarwin()) {
        blobby.linkFramework("OpenGL");
    } else {
        blobby.linkSystemLibrary("GL");
    }
    b.installArtifact(blobby);

    const blobby_server = b.addExecutable(.{
        .name = "blobby-server",
        .target = target,
        .optimize = optimize,
    });
    blobby_server.addIncludePath(.{ .path = "src" });
    blobby_server.addIncludePath(.{ .path = "deps/tinyxml" });
    blobby_server.addIncludePath(.{ .path = "deps/lua" });
    blobby_server.addCSourceFiles(&common_src, &cpp_flags);
    blobby_server.addCSourceFiles(&raknet_src, &cpp_flags);
    blobby_server.addCSourceFile(.{ .file = .{ .path = "src/server/servermain.cpp" }, .flags = &cpp_flags });
    blobby_server.linkLibrary(tinyxml);
    blobby_server.linkLibrary(lua);
    blobby_server.linkSystemLibrary("SDL2");
    blobby_server.linkSystemLibrary("physfs");
    b.installArtifact(blobby_server);

    const run_cmd = b.addRunArtifact(blobby);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const wasm_target = std.zig.CrossTarget{ .cpu_arch = .wasm32, .os_tag = .freestanding };
    const nanovg_dep = b.dependency("nanovg", .{ .target = wasm_target, .optimize = optimize });
    const nanovg = nanovg_dep.module("nanovg");

    const blobby_zig = b.addSharedLibrary(.{
        .name = "blobby",
        .target = wasm_target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });
    blobby_zig.addModule("nanovg", nanovg);
    blobby_zig.linkLibrary(nanovg_dep.artifact("nanovg"));
    blobby_zig.rdynamic = true;
    b.installArtifact(blobby_zig);
}
