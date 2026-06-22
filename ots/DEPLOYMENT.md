# Deployment

How to run the modernized **YurOTS** server (Tibia 7.6). YurOTS is **file-based**
(XML accounts/players, OTBM map) — there is no database to provision.

## Build from source and run

```bash
# Linux  : sudo apt install cmake g++ libxml2-dev libboost-regex-dev
# macOS  : brew install cmake boost libxml2
# Windows: MSYS2/MinGW64 -> pacman -S mingw-w64-x86_64-{gcc,cmake,ninja,libxml2,boost}
cd ots
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build --parallel
cmake --install build --prefix dist     # dist/ = binary + config.lua + data/
cd dist
./YurOTS
```

`cmake --install` stages a self-contained server folder: the `YurOTS` binary,
`config.lua`, and the whole `data/` tree (scripts, map, monsters, NPCs, items …) next
to it. Edit `config.lua` and `data/` freely, then run `./YurOTS` from that folder.

- The server reads `./config.lua` and `./data/` from the **current working directory**,
  so always start it from the staged folder (`cd dist`).
- It serves **login and game on a single port** (default `7171`).
- The build vendors **Lua 5.0** statically and links **libxml2** and **Boost.regex**;
  there is no external database or runtime service to start.

## Connect

Point a **Tibia 7.6** client at `127.0.0.1:7171`. For remote players, set `ip` in
`config.lua` to your public/host IP (the login step tells the client which IP to use
for the game connection). You can confirm the server is up without a client:

```bash
# OpenTibia status query -> XML server info
printf '\x06\x00\xff\xff\x69\x6e\x66\x6f' | nc -w 3 127.0.0.1 7171
```

## Notes

- World file names in `config.lua` use exact case (`data/world/test.otbm`), required on
  case-sensitive Linux/macOS filesystems.
- On `*nix` the engine refuses to run as `root` (`_NO_ROOT_PERMISSION_`); run it as a
  normal user.

## Coming later

Docker / docker-compose, a Pterodactyl egg and a GitHub-Actions release workflow (per-OS
`.zip` packages) mirror the sister project and are planned as a follow-up step; this pass
delivers the portable build-from-source path above.
