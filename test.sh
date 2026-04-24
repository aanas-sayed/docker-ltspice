#!/usr/bin/env bash
# test.sh – run an LTspice batch simulation inside Docker and validate results.
#
# Usage: ./test.sh [image]
#   image  Docker image to test (default: aanas0sayed/docker-ltspice)
#
# Exit codes:
#   0  all .meas checks passed
#   1  simulation failed or a measurement was not found in the log

set -euo pipefail

IMAGE="${1:-aanas0sayed/docker-ltspice}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test"
NETLIST="rc_filter.net"
LOG="${NETLIST%.net}.log"
LOG_PATH="$TEST_DIR/$LOG"

echo "==> LTspice headless batch test"
echo "    image  : $IMAGE"
echo "    netlist: $TEST_DIR/$NETLIST"
echo ""

# ── Clean up previous run artifacts ──────────────────────────────────────────
rm -f "$TEST_DIR"/"${NETLIST%.net}".{log,raw,op.raw,db}

# ── Run LTspice inside the container ─────────────────────────────────────────
# Wine maps Z:\ to the Linux root, so /sim inside the container becomes Z:\sim
docker run --rm \
    --platform linux/amd64 \
    --volume "$TEST_DIR:/sim" \
    "$IMAGE" /bin/bash -c '
set -e
    
NETLIST_WIN="Z:\\sim\\rc_filter.net"

echo "  [run]  ltspice -b \"$NETLIST_WIN\""
timeout 120 wine "/root/.wine/drive_c/Program Files/ADI/LTspice/LTspice.exe" -b -run "$NETLIST_WIN" || true
wineserver --wait 2>/dev/null || true

echo "  [done] simulation finished"
'

# ── Check log was produced ────────────────────────────────────────────────────
if [[ ! -f "$LOG_PATH" ]]; then
    echo "FAIL: log file was not created at $LOG_PATH"
    exit 1
fi

echo ""
echo "==> Simulation log ($LOG):"
echo "------------------------------------------------------------"
cat "$LOG_PATH"
echo "------------------------------------------------------------"

# ── Validate .meas results ────────────────────────────────────────────────────
echo ""
echo "==> Validating .meas results..."

PASS=1

# Extract the numeric value from a .meas log line, e.g.:
#   vout_max: MAX(v(out))=4.96832 FROM 0 TO 0.005  →  4.96832
meas_value() {
    grep -i "^${1}" "$LOG_PATH" 2>/dev/null | head -n1 | grep -oE '=[0-9eE.+-]+' | head -n1 | tr -d '='
}

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
    # Use awk for float comparison
    if awk -v v="$val" -v lo="$lo" -v hi="$hi" 'BEGIN{exit !(v>=lo && v<=hi)}'; then
        printf "  PASS  %-14s = %s  (expected [%s, %s])\n" "$name" "$val" "$lo" "$hi"
    else
        printf "  FAIL  %-14s = %s  (expected [%s, %s])\n" "$name" "$val" "$lo" "$hi"
        PASS=0
    fi
}

# V(out) max: 5·(1−e⁻⁵) ≈ 4.966 V — accept 4.9 to 5.0
check_meas_range "vout_max"  4.9   5.0
# Steady-state average (last 1 ms): > 4.9 V
check_meas_range "vout_ss"   4.9   5.0
# τ crossing time ≈ 1 ms — accept 0.9 ms to 1.1 ms
check_meas_range "tau_rise"  0.0009  0.0011

echo ""
if [[ "$PASS" -eq 1 ]]; then
    echo "==> All checks PASSED."
else
    echo "==> Test FAILED – one or more .meas values out of range."
    exit 1
fi
