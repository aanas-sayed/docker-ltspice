#!/usr/bin/env bash
# test.sh – run an LTspice batch simulation inside Docker and validate results.
#
# Usage: ./test.sh [image]
#   image  Docker image to test (default: aanas0sayed/docker-ltspice)
#
# Runs the simulation twice:
#   1. Default uid (the image's wineuser, uid 1000), only --volume mounted.
#   2. Hardened: --user=$(id -u):$(id -g) plus --cap-drop=ALL (no
#      --cap-add=DAC_OVERRIDE). Verifies the produced .raw file is owned by
#      the host user, proving the image can be consumed as a normal sandboxed
#      simulator without elevated capabilities.
#
# Exit codes:
#   0  all .meas checks passed in both runs and uid ownership matches in run 2
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

# stat -c works on GNU stat (Linux); -f '%u' is BSD/macOS.
file_uid() {
    if stat -c '%u' "$1" >/dev/null 2>&1; then
        stat -c '%u' "$1"
    else
        stat -f '%u' "$1"
    fi
}

# Bash-portable command that runs the simulation inside the container.
SIM_CMD='
set -e
NETLIST_WIN="Z:\\sim\\rc_filter.net"
echo "  [run]  ltspice -b \"$NETLIST_WIN\""
timeout 120 wine "$WINEPREFIX/drive_c/Program Files/ADI/LTspice/LTspice.exe" -b -run "$NETLIST_WIN" || true
wineserver --wait 2>/dev/null || true
echo "  [done] simulation finished"
'

# ── .meas validation helper ──────────────────────────────────────────────────
validate_meas() {
    local pass=1
    local check
    check() {
        local name="$1" lo="$2" hi="$3"
        local line val
        line=$(grep -i "^${name}" "$LOG_PATH" 2>/dev/null | head -n1)
        if [[ -z "$line" ]]; then
            echo "  FAIL  '${name}' not found in log"
            pass=0
            return
        fi
        if echo "$line" | grep -qi "FAIL"; then
            echo "  FAIL  $line"
            pass=0
            return
        fi
        if echo "$line" | grep -qi " AT "; then
            val=$(echo "$line" | grep -oiE 'AT [0-9eE.+-]+' | head -n1 | awk '{print $2}')
        else
            val=$(echo "$line" | grep -oE '=[0-9eE.+-]+' | head -n1 | tr -d '=')
        fi
        if awk -v v="$val" -v lo="$lo" -v hi="$hi" 'BEGIN{exit !(v>=lo && v<=hi)}'; then
            printf "  PASS  %-14s = %s  (expected [%s, %s])\n" "$name" "$val" "$lo" "$hi"
        else
            printf "  FAIL  %-14s = %s  (expected [%s, %s])\n" "$name" "$val" "$lo" "$hi"
            pass=0
        fi
    }
    check "vout_max"  4.9   5.0
    check "vout_ss"   4.9   5.0
    check "tau_rise"  0.0009  0.0011
    [[ "$pass" -eq 1 ]]
}

run_variant() {
    local label="$1"; shift
    echo ""
    echo "==> Variant: $label"
    rm -f "$TEST_DIR"/"${NETLIST%.net}".{log,raw,op.raw,db}
    docker run --rm \
        --platform linux/amd64 \
        --volume "$TEST_DIR:/sim" \
        "$@" \
        "$IMAGE" /bin/bash -c "$SIM_CMD"

    if [[ ! -f "$LOG_PATH" ]]; then
        echo "FAIL: log file was not created at $LOG_PATH"
        return 1
    fi

    echo ""
    echo "    Simulation log ($LOG):"
    echo "    ------------------------------------------------------------"
    sed 's/^/    /' "$LOG_PATH"
    echo "    ------------------------------------------------------------"

    echo ""
    echo "    Validating .meas results..."
    if ! validate_meas; then
        echo "    Variant '$label' FAILED – one or more .meas values out of range."
        return 1
    fi
    echo "    Variant '$label' PASSED."
}

echo "==> LTspice headless batch test"
echo "    image  : $IMAGE"
echo "    netlist: $TEST_DIR/$NETLIST"

# ── 1. Default run (image's built-in user) ───────────────────────────────────
run_variant "default user"

# ── 2. Hardened run: arbitrary --user, no DAC_OVERRIDE ──────────────────────
HOST_UID=$(id -u)
HOST_GID=$(id -g)
run_variant "host uid (--user=${HOST_UID}:${HOST_GID}, --cap-drop=ALL)" \
    --user="${HOST_UID}:${HOST_GID}" \
    --cap-drop=ALL

# Verify .raw file is owned by the host user.
if [[ ! -f "$RAW_PATH" ]]; then
    echo "FAIL: hardened run did not produce $RAW_PATH"
    exit 1
fi
RAW_UID=$(file_uid "$RAW_PATH")
if [[ "$RAW_UID" != "$HOST_UID" ]]; then
    echo "FAIL: $RAW (uid=$RAW_UID) is not owned by host uid $HOST_UID"
    exit 1
fi
echo "    .raw uid check: $RAW (uid=$RAW_UID) matches host uid $HOST_UID"

echo ""
echo "==> All checks PASSED in both variants."
