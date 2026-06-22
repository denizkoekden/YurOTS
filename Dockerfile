# syntax=docker/dockerfile:1
###############################################################################
# Dockerized YurOTS (Tibia 7.6, modernized)
#
# YurOTS stores accounts/players/map as XML/OTBM files — there is no database to
# provision and no GMP/MySQL/SQLite dependency. The image just builds the server
# and runs it; player/account saves live under data/ (mount a volume to persist).
###############################################################################

# ---------------------------------------------------------------- build stage
FROM ubuntu:24.04 AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake ninja-build g++ ca-certificates \
        libxml2-dev libboost-regex-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
# The CMake project lives in ots/ (config.lua + data/ are installed from there).
RUN cmake -S ots -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --parallel \
    && cmake --install build --prefix /opt/yurots

# -------------------------------------------------------------- runtime stage
FROM ubuntu:24.04 AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
        libxml2 libboost-regex1.83.0 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /opt/yurots --shell /usr/sbin/nologin otserv

COPY --from=build --chown=otserv:otserv /opt/yurots /opt/yurots
COPY --chown=otserv:otserv docker/entrypoint.sh /entrypoint.sh
COPY --chown=otserv:otserv docker/healthcheck.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh /healthcheck.sh /opt/yurots/YurOTS

WORKDIR /opt/yurots
USER otserv
EXPOSE 7171
# Health = the server answers the OpenTibia status query, not just an open port.
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 CMD /healthcheck.sh
ENTRYPOINT ["/entrypoint.sh"]
