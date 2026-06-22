#!/bin/sh
# Entrypoint for the Dockerized YurOTS server.
# Optionally patches the advertised IP / world settings in config.lua from
# environment variables (only when set), then launches the server. YurOTS is
# file-based, so there is no database connection to configure.
set -e
cd /opt/yurots

# Replace `key = "..."` (string value) in config.lua, escaping sed metachars.
set_str() {  # set_str <lua_key> <value>
    key="$1"; val="$2"
    esc=$(printf '%s' "$val" | sed -e 's/[&|\\]/\\&/g')
    sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = \"${esc}\"|" config.lua
}

# SERVER_IP is what the login server advertises to clients; set it to your
# public/host IP for remote players (default keeps whatever config.lua has).
[ -n "${SERVER_IP}" ]   && set_str ip        "${SERVER_IP}"
[ -n "${WORLD_NAME}" ]  && set_str worldname "${WORLD_NAME}"
[ -n "${WORLD_TYPE}" ]  && set_str worldtype "${WORLD_TYPE}"

echo ":: starting YurOTS (SERVER_IP=${SERVER_IP:-unset})"
exec ./YurOTS "$@"
