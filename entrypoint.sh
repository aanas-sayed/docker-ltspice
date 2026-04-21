#!/bin/bash
# entrypoint.sh – runs before every command inside the container
#
# Responsibilities (mirrors what scottyhardy's entrypoint.sh does):
#   1. Start Xvfb on DISPLAY :99 so Wine has a virtual screen to render into
#   2. Wait until the X server is actually accepting connections
#   3. First-run: initialise WINEPREFIX (creates the fake C: drive)
#   4. exec the user's command (bash by default, or anything passed to docker run)

set -e

XVFB_DISPLAY="${DISPLAY:-:99}"
DISPLAY_NUM="${XVFB_DISPLAY#:}"
XVFB_RESOLUTION="${XVFB_RESOLUTION:-1024x768x16}"

# ── 1. Prime Wine (no X server yet) ───────────────────────────────────────
#   The first wine invocation after a fresh container start triggers internal
#   service/init work (winebth, shell32, etc.).  If an X server IS available,
#   those services try to create windows and block forever.  Running LTspice
#   once with DISPLAY pointing to a non-existent server makes them fail fast
#   and complete their init.  The second run then works cleanly.
echo "[entrypoint] Priming Wine (display ${XVFB_DISPLAY}, no X yet)..."
export DISPLAY="${XVFB_DISPLAY}"
wine "/root/.wine/drive_c/Program Files/ADI/LTspice/LTspice.exe" -b 2>/dev/null || true
wineserver --wait 2>/dev/null || true
echo "[entrypoint] Wine primed."

# ── 2. Start Xvfb ─────────────────────────────────────────────────────────
rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"
echo "[entrypoint] Starting Xvfb on ${XVFB_DISPLAY} (${XVFB_RESOLUTION})"
Xvfb "${XVFB_DISPLAY}" -screen 0 "${XVFB_RESOLUTION}" -nolisten tcp 2>/dev/null &
XVFB_PID=$!

# Wait for the X server socket to appear (max 10 s)
for i in $(seq 1 20); do
    if [ -e "/tmp/.X11-unix/X${DISPLAY_NUM}" ]; then
        echo "[entrypoint] Xvfb ready (PID ${XVFB_PID})."
        break
    fi
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        echo "[entrypoint] ERROR: Xvfb exited unexpectedly!" >&2
        break
    fi
    sleep 0.5
done

export DISPLAY="${XVFB_DISPLAY}"

# ── 3. Hand off to the user's command ──────────────────────────────────────
exec "$@"