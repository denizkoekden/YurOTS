# Build PUC-Rio Lua 5.0.2 as a static library from the tarball bundled in the
# repository (source/libraries/lua-5.0.2.tar.gz). Vendoring guarantees byte-for-byte
# identical Lua semantics on Windows, Linux and macOS — the strongest 1:1 guarantee —
# and avoids the fact that Lua 5.0 is long gone from every system package manager.
#
# YurOTS uses the Lua 5.0 C API verbatim (lua_open / lua_dofile / lua_strlen and the
# manual luaopen_base/math/string/io calls in luascript/npc/spells/actions). Keeping
# real 5.0 means NONE of those call sites have to change.
#
# Produces the target: lua50  (PUBLIC include = include/, PRIVATE include = src/)

set(_LUA_TARBALL "${CMAKE_SOURCE_DIR}/source/libraries/lua-5.0.2.tar.gz")
set(_LUA_SHA256  "a6c85d85f912e1c321723084389d63dee7660b81b8292452b190ea7190dd73bc")
set(_LUA_DEST    "${CMAKE_BINARY_DIR}/_vendored")
set(_LUA_ROOT    "${_LUA_DEST}/lua-5.0.2")

if(NOT EXISTS "${_LUA_TARBALL}")
    message(FATAL_ERROR "Vendored Lua tarball missing: ${_LUA_TARBALL}")
endif()

# Pin the source: verify the tarball hash before using it.
file(SHA256 "${_LUA_TARBALL}" _got_sha)
if(NOT _got_sha STREQUAL _LUA_SHA256)
    message(FATAL_ERROR "Lua tarball hash mismatch.\n  expected ${_LUA_SHA256}\n  got      ${_got_sha}")
endif()

if(NOT EXISTS "${_LUA_ROOT}/include/lua.h")
    file(MAKE_DIRECTORY "${_LUA_DEST}")
    file(ARCHIVE_EXTRACT INPUT "${_LUA_TARBALL}" DESTINATION "${_LUA_DEST}")
endif()
if(NOT EXISTS "${_LUA_ROOT}/include/lua.h")
    message(FATAL_ERROR "Lua extraction failed: ${_LUA_ROOT}/include/lua.h not found")
endif()

# Core VM (src/). Excludes ltests.c (Lua's own test harness, needs LUA_USER_H) and
# the standalone interpreter (src/lua/lua.c) / compiler (src/luac/*.c).
set(_LUA_CORE
    lapi lcode ldebug ldo ldump lfunc lgc llex lmem lobject lopcodes lparser
    lstate lstring ltable ltm lundump lvm lzio)
# Standard libraries (src/lib/). 5.0 has no linit.c — libs are opened manually,
# exactly as YurOTS does.
set(_LUA_LIB
    lauxlib lbaselib ldblib liolib lmathlib ltablib lstrlib loadlib)

set(_LUA_SRCS "")
foreach(c ${_LUA_CORE})
    list(APPEND _LUA_SRCS "${_LUA_ROOT}/src/${c}.c")
endforeach()
foreach(c ${_LUA_LIB})
    list(APPEND _LUA_SRCS "${_LUA_ROOT}/src/lib/${c}.c")
endforeach()

add_library(lua50 STATIC ${_LUA_SRCS})
target_include_directories(lua50 SYSTEM PUBLIC  "${_LUA_ROOT}/include")
target_include_directories(lua50        PRIVATE "${_LUA_ROOT}/src")
set_target_properties(lua50 PROPERTIES POSITION_INDEPENDENT_CODE ON)

# Platform configuration for loadlib.c (package.loadlib). Linux + macOS both have
# dlopen; Windows auto-selects LoadLibrary via _WIN32 inside loadlib.c.
if(NOT WIN32)
    target_compile_definitions(lua50 PRIVATE USE_DLOPEN)
    target_link_libraries(lua50 PUBLIC m ${CMAKE_DL_LIBS})
endif()

# Lua 5.0 C is old; don't let its warnings break our build.
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(lua50 PRIVATE -w)
elseif(MSVC)
    target_compile_options(lua50 PRIVATE /w)
endif()
