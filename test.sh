#!/usr/bin/env bash
# test.sh – run an LTspice batch simulation inside Docker and validate results.
#
# Usage: ./test.sh [image]
#   image  Docker image to test (default: aanas0sayed/docker-ltspice)
#
# Runs the canonical hardened invocation: --user=$(id -u):$(id -g) plus
# --cap-drop=ALL (no --cap-add=DAC_OVERRIDE). This is the supported
# consumption pattern for the image. Verifies the produced .raw file is
# owned by the host user, proving the image works as a non-root sandboxed
# simulator without elevated capabilities.
#
# Exit codes:
#   0  all .meas checks passed and .raw is owned by host uid
#   1  simulation failed, a measurement was not found, or .raw uid mismatch

set -euo pipefail

IMAGE="${1:-aanas0sayed/docker-ltspice}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test"
NETLIST="rc_filter.net"
LOG="${NETLIST%.net}.log"
RAW="${NETLIST%.net}.raw"
LOG_PATH="$TEST_DIR/$LOG"
RAW_PATH="$TEST_DIR/$RAW"
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# stat -c works on GNU stat (Linux); -f '%u' is BSD/macOS.
file_uid() {
    if stat -c '%u' "$1" >/dev/null 2>&1; then
        stat -c '%u' "$1"
    else
        stat -f '%u' "$1"
    fi
}

echo "==> LTspice headless batch test"
echo "    image  : $IMAGE"
echo "    netlist: $TEST_DIR/$NETLIST"
echo "    flags  : --user=${HOST_UID}:${HOST_GID} --cap-drop=ALL"
echo ""

# ── Clean up previous run artifacts ──────────────────────────────────────────
rm -f "$TEST_DIR"/"${NETLIST%.net}".{log,raw,op.raw,db}

# ── Run LTspice inside the container ─────────────────────────────────────────
# Wine maps Z:\ to the Linux root, so /sim inside the container becomes Z:\sim.
docker run --rm \
    --platform linux/amd64 \
    --user="${HOST_UID}:${HOST_GID}" \
    --cap-drop=ALL \
    --volume "$TEST_DIR:/sim" \
    "$IMAGE" /bin/bash -c '
set -e

NETLIST_WIN="Z:\\sim\\rc_filter.net"

echo "  [run]  ltspice -b \"$NETLIST_WIN\""
timeout 120 wine "$WINEPREFIX/drive_c/Program Files/ADI/LTspice/LTspice.exe" -b -run "$NETLIST_WIN" || true
wineserver --wait 2>/dev/null || true

echo "  [done] simulation finished"
'

# ── Check log was produced ───────────────────────────────────────────────────
if [[ ! -f "$LOG_PATH" ]]; then
    echo "FAIL: log file was not created at $LOG_PATH"
    exit 1
fi

echo ""
echo "==> Simulation log ($LOG):"
echo "------------------------------------------------------------"
cat "$LOG_PATH"
echo "------------------------------------------------------------"

# ── Validate .meas results ───────────────────────────────────────────────────
echo ""
echo "==> Validating .meas results..."

PASS=1

check_meas_range() {
    local name="$1" lo="$2" hi="$3"
    local line val
    line=$(grep -i "^${name}" "$LOG_PATH" 2>/dev/null | head -n1)
    if [[ -z "$line" ]]; then
        echo "  FAIL  '${name}' not found in log"
        PASS=0
        return
    fi
    if echo "$line" | grep -qi "FAIL"; then
        echo "  FAIL  $line"
        PASS=0
        return
    fi
    # WHEN measurements format: "name: expr=threshold AT time"
    # Standard format:          "name: EXPR=value FROM ..."
    if echo "$line" | grep -qi " AT "; then
        val=$(echo "$line" | grep -oiE 'AT [0-9eE.+-]+' | head -n1 | awk '{print $2}')
    else
        val=$(echo "$line" | grep -oE '=[0-9eE.+-]+' | head -n1 | tr -d '=')
    fi
    if awk -v v="$val" -v lo="$lo" -v hi="$hi" 'BEGIN{exit !(v>=lo && v<=hi)}'; then
        printf "  PASS  %-14s = %s  (expected [%s, %s])\n" "$name" "$val" "$lo" "$hi"
    else
        printf "  FAIL  %-14s = %s  (expected [%s, %s])\n" "$name" "$val" "$lo" "$hi"
        PASS=0
    fi
}

check_meas_range "vout_max"  4.9   5.0
check_meas_range "vout_ss"   4.9   5.0
check_meas_range "tau_rise"  0.0009  0.0011

# ── Verify .raw file is owned by the host uid (proves no DAC bypass) ────────
if [[ ! -f "$RAW_PATH" ]]; then
    echo "  FAIL  $RAW was not produced"
    PASS=0
else
    RAW_UID=$(file_uid "$RAW_PATH")
    if [[ "$RAW_UID" != "$HOST_UID" ]]; then
        echo "  FAIL  $RAW uid=$RAW_UID does not match host uid $HOST_UID"
        PASS=0
    else
        printf "  PASS  %-14s uid=%s (matches host)\n" "$RAW" "$RAW_UID"
    fi
fi

echo ""
if [[ "$PASS" -eq 1 ]]; then
    echo "==> All checks PASSED."
else
    echo "==> Test FAILED – one or more checks did not pass."
    exit 1
fi
