#!/bin/bash
# entrypoint.sh – runs before every command inside the container.
#
# Responsibilities:
#   1. Materialise the WINEPREFIX from the on-image template so it is
#      owned by the current uid (required: Wine refuses to use a prefix
#      not owned by the running uid).
#   2. Prime Wine so first-run service init completes without an X server.
#   3. Either start a local Xvfb on :99 (headless / batch mode), or
#      respect the caller's DISPLAY if X11 forwarding was set up.
#   4. exec the user's command (bash by default).
#
# Runs as the unprivileged wineuser (uid 1000) by default. Also tolerates
# `docker run --user=<uid>:<gid>` for arbitrary uid/gid — the prefix copy
# inherits the current uid and /tmp is world-writable on caller systems.

set -e

# Caller-supplied DISPLAY (e.g. `-e DISPLAY=host.docker.internal:0` for X11
# forwarding from XQuartz). Empty if the user didn't pass one — in which
# case we run a private Xvfb on :99.
USER_DISPLAY="${DISPLAY:-}"
XVFB_DISPLAY=":99"
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

# ── 2. Prime Wine against a guaranteed-non-existent display ───────────────
#   The first wine invocation after a fresh container start triggers internal
#   service/init work (winebth, shell32, etc.).  If an X server IS available,
#   those services try to create windows and either block forever or finish
#   in a half-initialised state that breaks the next GUI launch.  Pin
#   DISPLAY to :99 here — Xvfb hasn't started yet, so the connection fails
#   fast and the services complete their non-GUI init cleanly. We override
#   any caller-supplied DISPLAY for this single step only.
echo "[entrypoint] Priming Wine (no X yet)..."
DISPLAY=":99" wine "$LTSPICE_EXE" -b 2>/dev/null || true
DISPLAY=":99" wineserver --wait 2>/dev/null || true
echo "[entrypoint] Wine primed."

# ── 3. Pick the runtime DISPLAY ───────────────────────────────────────────
# If the caller supplied DISPLAY (X11 forwarding, e.g. host.docker.internal:0
# from XQuartz on macOS), use it as-is and skip Xvfb. Otherwise start a
# private Xvfb on :99 for headless / batch operation.
if [ -n "$USER_DISPLAY" ]; then
    echo "[entrypoint] Using caller-provided DISPLAY=${USER_DISPLAY} (skipping Xvfb)"
    export DISPLAY="$USER_DISPLAY"
else
    rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}" 2>/dev/null || true
    echo "[entrypoint] Starting Xvfb on ${XVFB_DISPLAY} (${XVFB_RESOLUTION})"
    Xvfb "${XVFB_DISPLAY}" -screen 0 "${XVFB_RESOLUTION}" -nolisten tcp 2>/dev/null &
    XVFB_PID=$!
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
fi

# ── 4. Hand off to the user's command ──────────────────────────────────────
exec "$@"
