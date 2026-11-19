# Lua runtime

The shared runtime is PUC Lua **5.1.5**, built from `lua/` sources. It does not use LuaJIT headers, binaries, JIT compilation or `ffi`.

## Source provenance

Official archive: https://www.lua.org/ftp/lua-5.1.5.tar.gz

SHA-256: `2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333`.

The existing repository originally contained 52 byte-identical upstream source/header files. Two existing differences are retained: `llex.c` fixes the decimal separator to `.` for the old Android NDK, and `lua.c` has its standalone interpreter entry removed. `lua.c`, `luac.c` and `print.c` are not part of the runtime library. Lua's license remains in `lua/lua.h`. Android integration additionally changes `lgc.c`: weak-table mode strings are scanned within their recorded length, stopping at NUL as before. This avoids Android FORTIFY inferring a zero-sized buffer from Lua 5.1's header-followed-by-string layout; bounds checks remain enabled.

## Build and check

```sh
cmake -S scripting/lua -B /tmp/cocos-lua515 -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/cocos-lua515
ctest --test-dir /tmp/cocos-lua515 --output-on-failure
```

CMake consumers use the `lua515` static target and its exported headers. ndk-build consumers import `scripting/lua/lua` as `lua515_static`; `scripting/lua/proj.android` builds the existing Cocos bindings on top of it. Both use `lua/sources.txt`. Other tracked Windows/iOS project configurations and templates now compile the same source runtime rather than linking LuaJIT archives. Those legacy toolchains have not been compiled on this Mac.

## Migration

Lua 5.1 source scripts and the Cocos Lua C API bindings remain the interface. Rebuild every native component against these headers; do not mix old LuaJIT objects or libraries with the new runtime. LuaJIT bytecode (including the historical TestLua bytecode fixture) must be regenerated or replaced with source scripts. PUC Lua bytecode is also architecture dependent, so ship source scripts for the Mac/Android example. LuaJIT-specific `jit`, `ffi` and command-line bytecode compiler tools are not provided. Historical changelogs, excluded dependency paths and independent tools inside submodules are not rewritten as part of the runtime migration.

HelloLua platform build and real Cocos binding checks are delivered by the following platform task.
