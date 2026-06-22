###############################################################################
# YurOTS — modern, portable CMake build
#
# Goal: build the ORIGINAL YurOTS source (a 2000s-era OpenTibia server for
#       Tibia 7.6) on modern GCC / Clang / MSVC across Windows, Linux and macOS,
#       with 1:1 runtime behaviour preserved.
#
# The authoritative build manifest is source/devcpp/Makefile.win (the original
# Dev-C++ project): 49 .cpp entries (one stale, see below), the YUR_*/TLM_*/JD_*
# feature flags, BIN=YurOTS.
#
# YurOTS stores accounts/players/map as XML/OTBM files only — there is no SQL code
# in this engine — so unlike its sister project (evolution078ots) there is no
# storage backend switch, and no GMP/MySQL/SQLite dependency. Lua is 5.0 (vendored).
###############################################################################
cmake_minimum_required(VERSION 3.18)

project(YurOTS
    VERSION 0.9.4
    DESCRIPTION "YurOTS — OpenTibia Server for Tibia 7.6 (modernized build)"
    LANGUAGES C CXX)

# --- Standard ---------------------------------------------------------------
# Original was GCC 3.4.2 (C++03 + GNU extensions). gnu++14 is the minimal modern
# standard that keeps the GNU extensions the code relies on while letting us drop
# the removed-construct workarounds.
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)            # -> gnu++14
set(CMAKE_C_STANDARD 99)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "" FORCE)
endif()

# Help local (Homebrew) discovery on macOS.
if(APPLE)
    foreach(_p boost libxml2)
        execute_process(COMMAND brew --prefix ${_p}
            OUTPUT_VARIABLE _bp OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
        if(_bp AND EXISTS "${_bp}")
            list(APPEND CMAKE_PREFIX_PATH "${_bp}")
        endif()
    endforeach()
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

option(WARNINGS_AS_ERRORS "Treat warnings as errors (-Werror)" OFF)

###############################################################################
# Source manifest (mirrors source/devcpp/Makefile.win — 48 of its 49 entries)
###############################################################################
# mdump.cpp (Win32 minidump) is intentionally NOT in the Makefile manifest and is
# excluded here too. builtinaac.cpp is a STALE Makefile entry — the file does not
# exist in this checkout and nothing references it; the built-in AAC lives in
# aac.cpp/aac.h under YUR_BUILTIN_AAC. So it is dropped (48 units actually compile).
set(SRC_DIR "${CMAKE_SOURCE_DIR}/source")

set(SRC_UNITS
    aac account actions allocator chat commands container creature
    exception fileloader game guilds houses ioaccount ioaccountxml iomapbin
    iomapotbm iomapxml ioplayer ioplayerxml item itemloader items logger
    loginqueue luascript magic map md5 monster monsters networkmessage npc
    otserv player position protocol protocol76 pvparena readables scheduler
    spawn spells status summons thing tile tools)

set(SOURCES "")
foreach(u ${SRC_UNITS})
    list(APPEND SOURCES "${SRC_DIR}/${u}.cpp")
endforeach()

list(LENGTH SOURCES _nsrc)
message(STATUS "YurOTS: compiling ${_nsrc} translation units (XML storage, Lua 5.0)")

add_executable(YurOTS ${SOURCES})
target_include_directories(YurOTS PRIVATE "${SRC_DIR}")

###############################################################################
# Preprocessor defines (mirrors Makefile.win CXXFLAGS, 1:1)
###############################################################################
# YurOTS feature flags — part of the server's behaviour, must stay defined.
target_compile_definitions(YurOTS PRIVATE
    EXCEPTION_TRACER TLM_BUY_SELL TLM_SERVER_SAVE TLM_HOUSE_SYSTEM BDB_UTEVO_LUX
    WOLV_LOAD_NPC BD_HOUSE_WINDOW TR_ANTI_AFK ELEM_VIP_LIST TR_SUMMONS
    TRS_GM_INVISIBLE TLM_SKULLS_PARTY BRN_EXIVA SD_BURST_ARROW BDB_REPLACE_SPEARS
    BD_ITEM_LOOK SM_RELOAD_CONFIG JD_DEATH_LIST CT_EXANI_TERA CVS_DAY_CYCLE
    TJ_MONSTER_BLOOD JD_WANDS __DEBUG_PLAYERS__ YUR_CVS_MODS YUR_ICE_RAPIER
    YUR_AOL YUR_LOGIN_QUEUE YUR_MULTIPLIERS YUR_BOH YUR_NPC_EXT YUR_GUILD_SYSTEM
    YUR_CMD_EXT YUR_ITEM_EXT YUR_ACT_EXT YUR_NO_MONSTER_HEAL YUR_PVP_ARENA
    YUR_RINGS_AMULETS YUR_CONFIG_CAP YUR_FIGHT_MODE YUR_READABLES YUR_LEARN_SPELLS
    YUR_HEAL_EXHAUST YUR_SHUTDOWN YUR_ROOKGARD YUR_LIGHT_ITEM YUR_CLEAN_MAP
    YUR_GM_LOOK YUR_HIGH_LEVELS YUR_PREMIUM_PROMOTION YUR_INVISIBLE YUR_DRAINS
    YUR_BUILTIN_AAC)

# Assumption (stated in MODERNIZATION.md): load ./config.lua on every OS. The
# original *nix path was $HOME/.otserv/config.lua (defined by _HOMEDIR_CONF_ in
# otserv.cpp); we guard that define so -D__NO_HOMEDIR_CONF__ makes the build
# "download & run" (reads ./config.lua next to the binary).
target_compile_definitions(YurOTS PRIVATE __NO_HOMEDIR_CONF__)

# Platform macros — define the full set the code branches on, consistently.
if(WIN32)
    target_compile_definitions(YurOTS PRIVATE __WINDOWS__ WIN32 _WIN32
        WIN32_LEAN_AND_MEAN NOMINMAX)
    if(MSVC)
        target_compile_definitions(YurOTS PRIVATE _CRT_SECURE_NO_WARNINGS)
    endif()

    # Original YurOTS application icon (embedded by the Dev-C++ build).
    enable_language(RC)
    configure_file("${SRC_DIR}/devcpp/otserv.ico"
                   "${CMAKE_BINARY_DIR}/yurots.ico" COPYONLY)
    file(WRITE "${CMAKE_BINARY_DIR}/yurots.rc" "1 ICON \"yurots.ico\"\n")
    target_sources(YurOTS PRIVATE "${CMAKE_BINARY_DIR}/yurots.rc")
endif()

# Conservative 1:1 safety: the original GCC 3.4 did not do aggressive
# strict-aliasing optimization. The code type-puns the wire-protocol buffers;
# disable strict-aliasing project-wide so behaviour matches the original.
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(YurOTS PRIVATE -fno-strict-aliasing)
endif()

if(WARNINGS_AS_ERRORS)
    if(MSVC)
        target_compile_options(YurOTS PRIVATE /WX)
    else()
        target_compile_options(YurOTS PRIVATE -Werror)
    endif()
endif()

###############################################################################
# Dependencies
###############################################################################
# --- libxml2 (XML accounts/players/items, OTX maps) -------------------------
find_package(LibXml2 REQUIRED)
target_link_libraries(YurOTS PRIVATE LibXml2::LibXml2)

# --- Boost (regex compiled; bind/tokenizer header-only) ---------------------
find_package(Boost REQUIRED COMPONENTS regex)
target_link_libraries(YurOTS PRIVATE Boost::regex Boost::boost)
# No call site uses boost::bind placeholders -> silence the global-placeholder
# deprecation without changing behaviour.
target_compile_definitions(YurOTS PRIVATE BOOST_BIND_GLOBAL_PLACEHOLDERS)

# --- Lua 5.0 (vendored, static, hash-pinned) --------------------------------
include(BuildVendoredLua)            # defines target lua50 (PUC Lua 5.0.2)
target_link_libraries(YurOTS PRIVATE lua50)

# --- Threads + platform system libs -----------------------------------------
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
target_link_libraries(YurOTS PRIVATE Threads::Threads)

if(WIN32)
    target_link_libraries(YurOTS PRIVATE ws2_32)
else()
    target_link_libraries(YurOTS PRIVATE ${CMAKE_DL_LIBS})
endif()

###############################################################################
# Install / packaging layout (binary + runtime data next to it)
###############################################################################
install(TARGETS YurOTS RUNTIME DESTINATION .)
install(FILES "${CMAKE_SOURCE_DIR}/config.lua" DESTINATION .)
install(DIRECTORY "${CMAKE_SOURCE_DIR}/data" DESTINATION .)
