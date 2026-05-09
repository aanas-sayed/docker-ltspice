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
# Image runs as wineuser (uid 1000) by default. To also support
# --user=$(id -u):$(id -g) for arbitrary uid/gid, the prefix is shipped as
# a *template* (uid-agnostic) and the entrypoint copies it into a per-run
# location owned by the current uid. Wine refuses to use a prefix not
# owned by the running uid, so a simple chmod-only approach does not work.
RUN groupadd -g 1000 wineuser \
    && useradd -m -u 1000 -g 1000 -s /bin/bash wineuser

# ── 6. Wine env ────────────────────────────────────────────────────────────
# WINEPREFIX deliberately points into /tmp (tmpfs in callers) — the
# entrypoint materialises it from the on-image template on every fresh
# container start. The build-time prefix lives at /opt/wineprefix-template.
ENV HOME=/home/wineuser \
    WINEPREFIX=/tmp/wine-prefix \
    WINEDEBUG=-all \
    DISPLAY=:99

# ── 7. Install LTspice into a build-time prefix (as wineuser) ─────────────
USER wineuser
WORKDIR /home/wineuser
RUN Xvfb :99 -screen 0 1024x768x24 & \
    sleep 2 \
    && WINEPREFIX=/home/wineuser/.wine WINEDLLOVERRIDES="mscoree,mshtml=" \
        wineboot --init \
    && WINEPREFIX=/home/wineuser/.wine wineserver --wait \
    && wget -q -O /tmp/LTspice64.msi https://ltspice.analog.com/software/LTspice64.msi \
    && WINEPREFIX=/home/wineuser/.wine wine msiexec /i /tmp/LTspice64.msi /quiet /norestart \
    && WINEPREFIX=/home/wineuser/.wine wineserver --wait \
    && rm /tmp/LTspice64.msi \
    && rm -rf /tmp/.wine-* /tmp/wine-* \
    && kill %1 2>/dev/null || true

USER root

# ── 8. Split LTspice install out of the prefix; turn the prefix into a
#       uid-agnostic template ─────────────────────────────────────────────
# The 1.7 GB LTspice tree moves to /opt/ltspice (read-only at runtime),
# replaced by a relative symlink from inside the prefix so the registry
# entries written by msiexec still resolve. The slimmed-down prefix
# (~150 MB) becomes /opt/wineprefix-template — the entrypoint copies it
# per run into $WINEPREFIX, which makes the copy owned by the current
# uid and satisfies Wine's "prefix is not owned by you" check.
RUN mv "/home/wineuser/.wine/drive_c/Program Files/ADI/LTspice" /opt/ltspice \
    && ln -s /opt/ltspice "/home/wineuser/.wine/drive_c/Program Files/ADI/LTspice" \
    && mv /home/wineuser/.wine /opt/wineprefix-template \
    && find /opt/ltspice -type d -exec chmod a+rwx {} + \
    && find /opt/ltspice -type f -exec chmod a+rw {} + \
    && find /opt/wineprefix-template -type d -exec chmod a+rwx {} + \
    && find /opt/wineprefix-template -type f -exec chmod a+rw {} + \
    && chmod a+rwx /home/wineuser \
    && rm -rf /tmp/.X* /tmp/.wine-* /tmp/wine-*

# ── 9. Remove build-only tools ────────────────────────────────────────────
RUN apt-get purge -y --auto-remove wget p7zip-full unzip \
    && rm -rf /var/lib/apt/lists/*

# ── 10. Entrypoint + wrapper ──────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint
COPY wrappers/ltspice /usr/local/bin/ltspice
RUN chmod +x /usr/local/bin/entrypoint /usr/local/bin/ltspice

USER wineuser
WORKDIR /home/wineuser

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["/bin/bash"]
