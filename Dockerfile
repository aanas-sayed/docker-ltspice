# ─────────────────────────────────────────────────────────────────────────────
# ltspice – single image: lean Wine base + LTspice install
# Base: debian:bookworm-slim
# ─────────────────────────────────────────────────────────────────────────────

FROM debian:bookworm-slim

ARG WINE_BRANCH=stable
ARG WINE_VERSION=""
ARG DEBIAN_FRONTEND=noninteractive

# ── 1. Core packages ───────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
        locales \
        xvfb \
        cabextract \
        winbind \
        gosu \
        p7zip-full \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Locale ──────────────────────────────────────────────────────────────
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# ── 3. WineHQ repo ─────────────────────────────────────────────────────────
RUN dpkg --add-architecture i386 \
    && mkdir -p /etc/apt/keyrings \
    && wget -qO /etc/apt/keyrings/winehq.key \
        https://dl.winehq.org/wine-builds/winehq.key \
    && echo \
        "deb [signed-by=/etc/apt/keyrings/winehq.key] \
        https://dl.winehq.org/wine-builds/debian/ \
        bookworm main" \
        > /etc/apt/sources.list.d/winehq.list

# ── 4. Wine ────────────────────────────────────────────────────────────────
RUN apt-get update \
    && if [ -n "${WINE_VERSION}" ]; then \
           apt-get install -y --no-install-recommends \
               winehq-${WINE_BRANCH}=${WINE_VERSION} \
               wine-${WINE_BRANCH}=${WINE_VERSION} \
               wine-${WINE_BRANCH}-amd64=${WINE_VERSION} \
               wine-${WINE_BRANCH}-i386=${WINE_VERSION}; \
       else \
           apt-get install -y --no-install-recommends \
               winehq-${WINE_BRANCH}; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# ── 5. Wine env ────────────────────────────────────────────────────────────
ENV WINEPREFIX=/root/.wine \
    WINEDEBUG=-all \
    DISPLAY=:99

# ── 6. Install LTspice ─────────────────────────────────────────────────────
# Xvfb must be running before wineboot/msiexec – both need a display.
# We start it in the same RUN layer, do everything, then kill it.
# wget and other build-only tools are removed at the end of this layer.
RUN Xvfb :99 -screen 0 1024x768x24 & \
    sleep 2 \
    && WINEDLLOVERRIDES="mscoree,mshtml=" wineboot --init \
    && wineserver --wait \
    && wget -q -O /tmp/LTspice64.msi https://ltspice.analog.com/software/LTspice64.msi \
    && wine msiexec /i /tmp/LTspice64.msi /quiet /norestart \
    && wineserver --wait \
    && rm /tmp/LTspice64.msi \
    && rm -rf /tmp/.wine-* /tmp/wine-* \
    && kill %1 2>/dev/null || true

# ── 7. Remove build-only tools ────────────────────────────────────────────
RUN apt-get purge -y --auto-remove wget p7zip-full unzip \
    && rm -rf /var/lib/apt/lists/*

# ── 8. Entrypoint ──────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

# ── 9. LTspice wrapper ─────────────────────────────────────────────────────
COPY wrappers/ltspice /usr/local/bin/ltspice
RUN chmod +x /usr/local/bin/ltspice

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["/bin/bash"]