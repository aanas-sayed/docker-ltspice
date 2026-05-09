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

# ── 5. Unprivileged user ───────────────────────────────────────────────────
# Image runs as wineuser (uid 1000) by default. The prefix is chmod a+rwX'd
# below so the image still works under `--user=$(id -u):$(id -g)` for any uid.
RUN groupadd -g 1000 wineuser \
    && useradd -m -u 1000 -g 1000 -s /bin/bash wineuser

# ── 6. Wine env ────────────────────────────────────────────────────────────
ENV HOME=/home/wineuser \
    WINEPREFIX=/home/wineuser/.wine \
    WINEDEBUG=-all \
    DISPLAY=:99

# ── 7. Install LTspice (as wineuser) ──────────────────────────────────────
USER wineuser
WORKDIR /home/wineuser
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

USER root

# Make the prefix tree readable + writable by any uid, so the image works
# under `docker run --user=<arbitrary>:<arbitrary>` without CAP_CHOWN.
# Use find with -type so we never dereference the dosdevices/z: -> /
# symlink that wineboot installs in the prefix.
RUN find /home/wineuser -type d -exec chmod a+rwx {} + \
    && find /home/wineuser -type f -exec chmod a+rw {} +

# ── 8. Remove build-only tools ────────────────────────────────────────────
RUN apt-get purge -y --auto-remove wget p7zip-full unzip \
    && rm -rf /var/lib/apt/lists/*

# ── 9. Entrypoint ──────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

# ── 10. LTspice wrapper ────────────────────────────────────────────────────
COPY wrappers/ltspice /usr/local/bin/ltspice
RUN chmod +x /usr/local/bin/ltspice

USER wineuser
WORKDIR /home/wineuser

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["/bin/bash"]
