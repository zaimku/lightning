#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="${BASE_DIR:-${HOME}/lightning-herominers}"
BIN_DIR="${BIN_DIR:-${BASE_DIR}/bin}"
PID_FILE="${BASE_DIR}/miner.pid"
LAUNCHER_PID_FILE="${BASE_DIR}/launcher.pid"

pid=""
if [[ -f "$PID_FILE" ]]; then
    pid="$(tr -dc '0-9' < "$PID_FILE")"
fi
if { [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; } && command -v pgrep >/dev/null 2>&1; then
    pid="$(pgrep -o -f "^${BIN_DIR}/peakminer-[0-9.]+ --coin pearl" || true)"
fi

if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PID_FILE" "$LAUNCHER_PID_FILE"
    echo "STATUS=ALREADY_STOPPED"
    exit 0
fi

echo "Menghentikan PeakMiner PID ${pid}..."
kill -TERM "$pid"
for _ in {1..15}; do
    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE" "$LAUNCHER_PID_FILE"
        echo "STATUS=STOPPED"
        exit 0
    fi
    sleep 1
done

echo "PeakMiner tidak berhenti setelah 15 detik; mengirim SIGKILL." >&2
kill -KILL "$pid" 2>/dev/null || true
rm -f "$PID_FILE" "$LAUNCHER_PID_FILE"
echo "STATUS=STOPPED_FORCEFULLY"
