#!/bin/bash
# Applies the Pterodactyl panel variables to config.lua, then launches the server.
# Only NON-EMPTY variables are applied, so any setting you leave blank keeps whatever
# you edited directly in config.lua via the file manager / SFTP. config.lua and the
# whole data/ tree (scripts, map, monsters, npc, ...) live here and stay editable.
cd /home/container
C=config.lua

sstr() { [ -z "$2" ] || sed -i "s|^[[:space:]]*$1[[:space:]]*=.*|$1 = \"$2\"|" "$C"; }   # string value
snum() { [ -z "$2" ] || sed -i "s|^[[:space:]]*$1[[:space:]]*=.*|$1 = $2|"     "$C"; }   # numeric value

# Network: the bind port comes from the Pterodactyl allocation; PUBLIC_IP is what
# the login server advertises to clients (set it to your node's public IP).
sstr port       "${SERVER_PORT}"     # YurOTS stores port as a quoted string
sstr ip         "${PUBLIC_IP}"

# World
sstr worldname  "${WORLD_NAME}"
sstr worldtype  "${WORLD_TYPE}"
sstr maxplayers "${MAX_PLAYERS}"     # stored as a quoted string in config.lua

# Rates (expmul is the only simple scalar multiplier in YurOTS' config.lua;
# weaponmul/distmul/shieldmul/manamul are per-vocation tables, left to manual editing)
snum expmul     "${RATE_EXP}"

exec ./YurOTS
