# YurOTS — OpenTibia Server for Tibia 7.6

This repo contains a very old, outdated engine for **Tibia 7.6** (engine version
`0.9.4f`), originally written by **Yurez** and built only with Dev-C++ / MinGW on
Windows.

Like its sister repo [evolution078ots](https://github.com/denizkoekden/evolution078ots),
I used modern technology to bring the nostalgia back to life — I let **Claude Opus 4.8**
fix the toolchain so the classic YurOTS server builds and runs on modern platforms,
**with its original behaviour preserved**.

---

## Modernized build (Windows / Linux / macOS)

The original sources only built with Dev-C++ / MinGW (Windows). They now build
unchanged-in-behaviour with modern GCC / Clang / MSVC via **CMake**, with **Lua 5.0**
vendored from this repo. See **[MODERNIZATION.md](ots/MODERNIZATION.md)** for the full list
of changes, assumptions, and the fixed pre-existing bugs (including a 64-bit map/items
loader bug and a corrupted accented-letter table).

YurOTS stores everything as **XML / OTBM files** — there is no SQL backend, and no
GMP / MySQL / SQLite dependency.

### Quick start

```bash
# Linux  : sudo apt install cmake g++ libxml2-dev libboost-regex-dev
# macOS  : brew install cmake boost libxml2
# Windows: MSYS2/MinGW64 -> pacman -S mingw-w64-x86_64-{gcc,cmake,ninja,libxml2,boost}
cd ots
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build --parallel
cmake --install build --prefix dist     # ready-to-run server folder
cd dist && ./YurOTS                      # reads ./config.lua and ./data, listens on 7171
```

Connect a **Tibia 7.6** client to `127.0.0.1:7171` (login and game share one port).
Set `ip` in `config.lua` to your public/host IP for remote players. World file names
in `config.lua` use exact case (`data/world/test.otbm`), required on case-sensitive
Linux/macOS filesystems.

> The original engine has known crash/stability bugs typical of this era of OTServ
> (party/trade spam, depot/parcel overflow, etc.); the modernization **preserves**
> them rather than silently changing behaviour. Two genuine bugs that the old 32-bit
> Windows build hid were fixed because they are deterministic on a modern 64-bit
> toolchain (see [MODERNIZATION.md](ots/MODERNIZATION.md) §4).

See **[DEPLOYMENT.md](ots/DEPLOYMENT.md)** for how to run it.
