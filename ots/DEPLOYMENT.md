# Deployment

Four ways to run the modernized **YurOTS** server (Tibia 7.6). YurOTS is
**file-based** (XML accounts/players, OTBM map) — there is no database to provision.

> Paths below are relative to the **repository root** (the Docker, Pterodactyl and CI
> files live there); the CMake project itself is under `ots/`.

## 1. Docker Compose (one command)

```bash
docker compose up --build
```

- Builds the server and runs it; connect a **Tibia 7.6** client to `127.0.0.1:7171`
  (login and game share one port).
- For remote players, set `SERVER_IP` in [docker-compose.yml](../docker-compose.yml)
  to your public/host IP (`WORLD_NAME` / `WORLD_TYPE` are also patchable via env).
- Player/account saves persist in the `yurots-data` volume (seeded from the image's
  `data/` on first start). The server runs as a non-root user (the engine refuses root).

## 2. Pterodactyl egg

[`pterodactyl/egg-yurots.json`](../pterodactyl/egg-yurots.json) — self-contained, no
external database. It **builds from source on install** into the server's file area, so
`config.lua` and the entire `data/` tree (scripts, map, monsters, NPCs, …) are editable
via the panel file manager and SFTP.

Common settings are exposed as **panel variables** (public IP, world name, world type,
max players, exp rate). They are applied to `config.lua` on each start via
[`pterodactyl/start.sh`](../pterodactyl/start.sh) — **only when set**, so any value you
leave blank keeps whatever you edited in `config.lua` directly. The listen port follows
the Pterodactyl allocation; `GIT_REF` selects the branch/tag to build (default `master`).

## 3. Prebuilt release packages

Pushing a `v*` tag triggers [`.github/workflows/release.yml`](../.github/workflows/release.yml),
which builds self-contained per-OS `.zip` packages for **Windows, Linux and macOS**
(MinGW / GCC / Clang) and publishes them as a GitHub Release. Download, unzip, and run
`./run.sh` (or `run.bat` / `./YurOTS`). See the package's `README-PACKAGE.txt`.

## 4. Build from source and run

```bash
# Linux  : sudo apt install cmake g++ libxml2-dev libboost-regex-dev
# macOS  : brew install cmake boost libxml2
# Windows: MSYS2/MinGW64 -> pacman -S mingw-w64-x86_64-{gcc,cmake,ninja,libxml2,boost}
cd ots
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build --parallel
cmake --install build --prefix dist     # dist/ = binary + config.lua + data/
cd dist && ./YurOTS
```

`cmake --install` stages a self-contained server folder: the `YurOTS` binary,
`config.lua`, and the whole `data/` tree next to it. Start it **from that folder** (the
server reads `./config.lua` and `./data/` from the current working directory).

## Connect / verify

Point a **Tibia 7.6** client at `127.0.0.1:7171`. You can confirm the server is up
without a client:

```bash
# OpenTibia status query -> XML server info
printf '\x06\x00\xff\xff\x69\x6e\x66\x6f' | nc -w 3 127.0.0.1 7171
```

## Notes

- This engine serves **login and game on a single port** (default `7171`).
- World file names in `config.lua` use exact case (`data/world/test.otbm`), required on
  case-sensitive Linux/macOS filesystems.
- On `*nix` the engine refuses to run as `root` (`_NO_ROOT_PERMISSION_`); run it as a
  normal user (the Docker image already does).
