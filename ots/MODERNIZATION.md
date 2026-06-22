# Modernization of OpenTibia Server "YurOTS" (Tibia 7.6)

This document records how the original 2000s-era **YurOTS** sources (a Dev-C++ /
MinGW-GCC-3.4.2, Windows-only OTServ fork for **Tibia 7.6**, engine version
`0.9.4f`) were made to build and run with modern compilers (GCC 13+, Clang 16+,
MSVC 2022) on **Windows, Linux and macOS**, **without changing runtime behaviour**.

The guiding rule for every change below — the same one used for the sister project
[evolution078ots](https://github.com/denizkoekden/evolution078ots): *preserve the
original behaviour 1:1; only touch what a modern toolchain rejects, and isolate
anything that could affect observable behaviour.*

> Status: **builds clean and runs on macOS (Apple clang, arm64)** — loads the Lua
> config, all XML data, the binary `items.otb` and the OTBM map, binds port 7171 and
> answers the OpenTibia status query (`version="0.9.4f"`). The CMake build is written
> to be portable to GCC/Linux and MinGW/Windows by the same rules.

---

## 1. New, portable build system (CMake)

The original authoritative build was `source/devcpp/Makefile.win` (the Dev-C++
project). The MSVC project under `source/msvc/` is treated as secondary. The new
files:

| File | Purpose |
|------|---------|
| `CMakeLists.txt` | Portable build; source manifest and `-D` feature flags mirror `Makefile.win`. |
| `cmake/BuildVendoredLua.cmake` | Builds **PUC Lua 5.0.2** as a static lib from the repo's own `source/libraries/lua-5.0.2.tar.gz` (SHA256-pinned) — identical Lua on every OS. |
| `source/libraries/lua-5.0.2.tar.gz` | The vendored Lua 5.0.2 source tarball. |

### Storage backend

Unlike evolution078ots, **YurOTS has no SQL code at all** — accounts, players and
the map are stored as **XML / OTBM files**. There is therefore no storage switch and
**no GMP, MySQL or SQLite dependency**.

### Dependencies

libxml2, Boost (regex compiled; bind/tokenizer header-only), and **Lua 5.0**
(vendored). **Boost is kept** (not replaced by `std::`). **Lua 5.0 is kept** (not
ported to 5.1/5.4): the engine uses the 5.0 C API verbatim (`lua_open`, `lua_dofile`,
`lua_strlen`, and the manual `luaopen_base/math/string/io` calls in
`luascript`/`npc`/`spells`/`actions`), so vendoring real 5.0 is the strongest 1:1
guarantee and changes zero call sites.

### Source manifest

The 49 `.cpp` entries listed in `Makefile.win`, **minus `builtinaac.cpp`** — a stale
entry: the file does not exist in this checkout and nothing references it (the built-in
AAC lives in `aac.cpp`/`aac.h` under `YUR_BUILTIN_AAC`). `mdump.cpp` (the Win32 minidump
helper) is not in the manifest and stays out. Net: **48 translation units**.

---

## 2. How to build

```bash
# Linux  : sudo apt install cmake g++ libxml2-dev libboost-regex-dev
# macOS  : brew install cmake boost libxml2
# Windows: MSYS2/MinGW64 -> pacman -S mingw-w64-x86_64-{gcc,cmake,ninja,libxml2,boost}
cd ots
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build --parallel
cmake --install build --prefix dist     # dist/ is a ready-to-run server folder
cd dist && ./YurOTS                      # reads ./config.lua and ./data, listens on 7171
```

---

## 3. Source changes (all behaviour-preserving)

Every change is also commented inline at the call site (search for `modernization:`).

### 3.1 Fixed-width integer types
- **`definitions.h`**: the hand-rolled `typedef unsigned long long uint64_t;`, the
  Windows `uint32/16/8` typedefs and the `*nix` `#include <stdint.h>` collided with
  the standard `<stdint.h>` on modern LP64 systems (`uint64_t` is `unsigned long`
  there). Replaced by a single `#include <cstdint>`; the Win32 spelling `__int64` is
  kept as an alias on `*nix`.
- **`luascript.h`**: now includes `definitions.h` so `__int64` (used by `exp_t`) is
  visible in every translation unit.

### 3.2 Removed compiler-rejected constructs
- **`items.h`**: `__gnu_cxx::hash_map` / `stdext::hash_map` → `std::unordered_map`
  (same average-O(1) semantics; no call site depends on iteration order).
- **"Extra qualification on member"** (ISO C++ hard error): in-class member
  definitions written `Class::member` lost the redundant prefix — `FileLoader::writeData`
  (`fileloader.h`), `Item::getText` (`item.h`), `LuaScript::setField` (`luascript.h`),
  `SpellScript::getSpell` (`spells.h`).
- **`fileloader.cpp`**: `abs()` on an `unsigned long` difference was ambiguous under
  modern overload sets → `labs()` on the signed difference (same intended magnitude).

### 3.3 Platform layer
- **Sockets** (`otsystem.h`): `<winsock.h>` (1.1) → `<winsock2.h>` + `<ws2tcpip.h>`.
  CMake defines `WIN32_LEAN_AND_MEAN` so `<windows.h>` does not pull the old winsock first.
- **Clock** (`otsystem.h`, `tools.cpp`): `_ftime`/`ftime`/`_timeb`/`struct timeb`
  (removed from modern glibc, deprecated on macOS) → `std::chrono`, returning the same
  milliseconds-since-epoch (`OTSYS_TIME`, both branches) / elapsed-seconds (`timer()`) value.

### 3.4 MSVC/MinGW-only integer↔string functions
- `ltoa`/`_ultoa`/`_i64toa`/`_ui64toa` (`tools.cpp` `str()` overloads) → `snprintf`
  base-10; `_atoi64` (`ioplayerxml.cpp`, `monsters.cpp`) → `strtoll`. Byte-identical output.

### 3.5 64-bit pointer round-trip through Lua
The engine hands a C++ object address to a Lua script as a number and casts it back
(`setGlobalNumber("addressOf…", (int)ptr)` → `(Type*)(int)lua_tonumber(...)`). `(int)`
**truncated the pointer on 64-bit**. Widened the whole round-trip to `intptr_t`
(`setGlobalNumber` parameter in `luascript.h`/`.cpp`, and the write/read sites in
`actions.cpp`, `npc.cpp`, `spells.cpp`). Lua 5.0 numbers are `double`, which represent
user-space addresses (< 2^48) exactly.

### 3.6 Config path
- **`otserv.cpp`**: the `*nix` build read `$HOME/.otserv/config.lua` (hard-coded
  `#define _HOMEDIR_CONF_`). That define is now guarded by `#ifndef __NO_HOMEDIR_CONF__`,
  and CMake defines `__NO_HOMEDIR_CONF__`, so the server reads `./config.lua` next to
  the binary on every OS ("download & run"). See Assumptions.

---

## 4. Pre-existing bugs found and fixed (needed to build/run on a modern toolchain)

1. **64-bit binary file reading (OTB items + OTBM map).** The on-disk OTB/OTBM format
   stores 32-bit fields, but the loaders read them through `unsigned long`, which is
   **8 bytes on LP64**. The header version `fread(&v, sizeof(unsigned long), …)` read 8
   bytes and judged the file version invalid; `GET_ULONG` desynced every property
   stream; `sizeof(VERSIONINFO)`/`sizeof(OTBM_root_header)` no longer matched the
   file's records. With 0 players this is invisible on the original 32-bit Windows
   build, so `items.otb` and every map failed to load on a 64-bit build. Fixed by
   making the on-disk 32-bit fields fixed-width `uint32_t`:
   `fileloader.h` `GET_ULONG`, `fileloader.cpp` header read, `itemloader.h` `flags_t`
   and `VERSIONINFO`, `iomapotbm.cpp` `flags_t` and `OTBM_root_header`.
2. **`tools.cpp` `upchar()` data corruption** — the accented-letter upper-casing table
   had every CP1252 high byte corrupted to U+FFFD (the Unicode replacement char) in the
   archive's history, collapsing all 31 branches to one value (and no longer compiling
   as `char` literals). Reconstructed as the standard Latin-1/CP1252 mapping
   (à..ö, ø..þ → −0x20; ÿ → Ÿ/0x9F). **Assumption** — see below. (The hexdump
   non-printable placeholder, corrupted the same way, was restored to `'.'`.)
3. **Stale `Makefile.win` manifest entry** — `builtinaac.cpp` is listed but does not
   exist; dropped from the build.

---

## 5. Stated assumptions

- **The original was Windows/Dev-C++ only.** `Makefile.win` is the source of truth for
  the file manifest and feature flags; the MSVC project is secondary.
- **Config path**: the packages define `__NO_HOMEDIR_CONF__` and read `./config.lua`
  on every OS so the build is "download & run".
- **Lua 5.0 vendoring** is the most faithful choice: it keeps the engine's Lua 5.0 C
  API and number/string semantics byte-for-byte, with no script-facing change.
- **`upchar()` reconstruction** restores the *original YurOTS* behaviour, which is more
  faithful than preserving the corrupted (uncompilable) archive state.

---

## 6. Not done in this step (deliberately)

Docker / docker-compose, a Pterodactyl egg, and a GitHub-Actions release workflow were
left for a follow-up step (this pass is the portable build + the source modernization +
these docs). YurOTS has no separate remote-control / admin GUI to port.
