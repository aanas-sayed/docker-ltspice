#!/bin/bash
# entrypoint.sh – runs before every command inside the container
#
# Responsibilities (mirrors what scottyhardy's entrypoint.sh does):
#   1. Start Xvfb on DISPLAY :99 so Wine has a virtual screen to render into
#   2. Wait until the X server is actually accepting connections
#   3. First-run: initialise WINEPREFIX (creates the fake C: drive)
#   4. exec the user's command (bash by default, or anything passed to docker run)

set -e

# ── 1. Start Xvfb if not already running ───────────────────────────────────
XVFB_DISPLAY="${DISPLAY:-:99}"
XVFB_RESOLUTION="${XVFB_RESOLUTION:-1024x768x24}"

if ! pgrep -x Xvfb > /dev/null 2>&1; then
    echo "[entrypoint] Starting Xvfb on ${XVFB_DISPLAY} (${XVFB_RESOLUTION})"
    Xvfb "${XVFB_DISPLAY}" -screen 0 "${XVFB_RESOLUTION}" -nolisten tcp &
    XVFB_PID=$!

    # ── 2. Wait for the X server to be ready (max 10 s) ────────────────────
    for i in $(seq 1 20); do
        if xdpyinfo -display "${XVFB_DISPLAY}" > /dev/null 2>&1; then
            echo "[entrypoint] Xvfb ready."
            break
        fi
        sleep 0.5
    done
fi

export DISPLAY="${XVFB_DISPLAY}"

# ── 3. Initialise Wine prefix on first run ─────────────────────────────────
#   wineboot --init creates ~/.wine (WINEPREFIX) and runs the initial Wine
#   setup. We suppress the GUI and set WINEDLLOVERRIDES to skip the Mono/
#   Gecko install dialogs that would otherwise block forever in a headless env.
# if [ ! -f "${WINEPREFIX}/system.reg" ]; then
#     echo "[entrypoint] Initialising Wine prefix at ${WINEPREFIX} …"
#     WINEDLLOVERRIDES="mscoree,mshtml=" \
#     DISPLAY="${XVFB_DISPLAY}" \
#     wineboot --init 2>/dev/null
#     # Wait for wineserver to finish (important before running any wine command)
#     wineserver --wait
#     echo "[entrypoint] Wine prefix ready."
# fi

# ── 4. Hand off to the user's command ──────────────────────────────────────
exec "$@"