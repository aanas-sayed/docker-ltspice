#!/bin/bash
# entrypoint.sh – runs before every command inside the container.
#
# Responsibilities:
#   1. Materialise the WINEPREFIX from the on-image template so it is
#      owned by the current uid (required: Wine refuses to use a prefix
#      not owned by the running uid).
#   2. Prime Wine so first-run service init completes without an X server.
#   3. Start Xvfb on DISPLAY :99 so subsequent Wine calls have a display.
#   4. exec the user's command (bash by default).
#
# Runs as the unprivileged wineuser (uid 1000) by default. Also tolerates
# `docker run --user=<uid>:<gid>` for arbitrary uid/gid — the prefix copy
# inherits the current uid and /tmp is world-writable on caller systems.

set -e

XVFB_DISPLAY="${DISPLAY:-:99}"
DISPLAY_NUM="${XVFB_DISPLAY#:}"
XVFB_RESOLUTION="${XVFB_RESOLUTION:-1024x768x16}"

# Defensive: an arbitrary --user uid often has no /etc/passwd entry,
# leaving HOME unset. Wine and other tools then fall back to "/" which
# is read-only. Force a sensible HOME.
export HOME="${HOME:-/home/wineuser}"
export WINEPREFIX="${WINEPREFIX:-/tmp/wine-prefix}"
# Several Wine code paths look up the username via getpwuid(); when the
# uid is not in /etc/passwd this returns NULL and Wine creates an
# unnamed users/ subdir. Pinning $LOGNAME/$USER avoids that and matches
# the username baked into the prefix template at build time.
export LOGNAME="${LOGNAME:-wineuser}"
export USER="${USER:-wineuser}"

TEMPLATE=/opt/wineprefix-template

# ── 1. Materialise the prefix ─────────────────────────────────────────────
if [ ! -d "$WINEPREFIX" ]; then
    echo "[entrypoint] Materialising WINEPREFIX at ${WINEPREFIX} (uid $(id -u))"
    # cp -a would try to preserve owner and fail when run as non-root.
    # --no-preserve=ownership keeps mode/timestamps/symlinks but lets the
    # copy inherit the running uid — which is exactly what Wine needs.
    cp -a --no-preserve=ownership "$TEMPLATE" "$WINEPREFIX"
fi

LTSPICE_EXE="${WINEPREFIX}/drive_c/Program Files/ADI/LTspice/LTspice.exe"

# ── 2. Prime Wine (no X server yet) ───────────────────────────────────────
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

# ── 3. Start Xvfb ─────────────────────────────────────────────────────────
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

# ── 4. Hand off to the user's command ──────────────────────────────────────
exec "$@"
