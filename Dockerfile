# ─────────────────────────────────────────────────────────────────────────────
# ltspice – single image: lean Wine base + LTspice install
# Base: debian:bookworm-slim
# ─────────────────────────────────────────────────────────────────────────────

FROM debian:bookworm-slim

ARG WINE_BRANCH=stable
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
    && apt-get install -y --install-recommends \
        winehq-${WINE_BRANCH} \
    && rm -rf /var/lib/apt/lists/*

# ── 5. Wine env ────────────────────────────────────────────────────────────
ENV WINEPREFIX=/root/.wine \
    DISPLAY=:99

# ── 6. Install LTspice ─────────────────────────────────────────────────────
# Xvfb must be running before wineboot/msiexec – both need a display.
# We start it in the same RUN layer, do everything, then kill it.
RUN wget -q -O /tmp/LTspice64.msi https://ltspice.analog.com/software/LTspice64.msi \
    && wine msiexec /i /tmp/LTspice64.msi /quiet /norestart \
    && rm /tmp/LTspice64.msi
    
# ── 7. Entrypoint ──────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

# ── 8. LTspice wrapper ─────────────────────────────────────────────────────
COPY wrappers/ltspice /usr/local/bin/ltspice
RUN chmod +x /usr/local/bin/ltspice

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["/bin/bash"]