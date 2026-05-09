#!/bin/bash
# entrypoint.sh – runs before every command inside the container
#
# Responsibilities:
#   1. Prime Wine so first-run service init completes
#   2. Start Xvfb on DISPLAY :99 so Wine has a virtual screen
#   3. Wait until the X server is actually accepting connections
#   4. exec the user's command (bash by default, or anything passed to docker run)
#
# Runs as the unprivileged wineuser by default. Also tolerates being run
# under `docker run --user=<uid>:<gid>` for arbitrary uid/gid — the image's
# WINEPREFIX has been chmod a+rwX'd at build time so any uid can use it.

set -e

XVFB_DISPLAY="${DISPLAY:-:99}"
DISPLAY_NUM="${XVFB_DISPLAY#:}"
XVFB_RESOLUTION="${XVFB_RESOLUTION:-1024x768x16}"

# Ensure HOME points at the prefix's parent even when --user is an arbitrary
# uid that has no /etc/passwd entry (in which case HOME would otherwise be
# unset or "/").
export HOME="${HOME:-/home/wineuser}"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"

LTSPICE_EXE="${WINEPREFIX}/drive_c/Program Files/ADI/LTspice/LTspice.exe"

# ── 1. Prime Wine (no X server yet) ───────────────────────────────────────
#   The first wine invocation after a fresh container start triggers internal
#   service/init work (winebth, shell32, etc.).  If an X server IS available,
#   those services try to create windows and block forever.  Running LTspice
#   once with DISPLAY pointing to a non-existent server makes them fail fast
#   and complete their init.  The second run then works cleanly.
echo "[entrypoint] Priming Wine (display ${XVFB_DISPLAY}, no X yet)..."
export DISPLAY="${XVFB_DISPLAY}"
wine "$LTSPICE_EXE" -b 2>/dev/null || true
wineserver --wait 2>/dev/null || true
echo "[entrypoint] Wine primed."

# ── 2. Start Xvfb ─────────────────────────────────────────────────────────
rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}" 2>/dev/null || true
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
