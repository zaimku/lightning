#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-${HOME}/lightning-herominers}"
LAUNCHER_LOG="${BASE_DIR}/launcher.log"
LAUNCHER_PID_FILE="${BASE_DIR}/launcher.pid"
DURATION_SECS="${1:-86400}"
WORKER_OVERRIDE="${2:-${WORKER_NAME:-}}"

if ! [[ "$DURATION_SECS" =~ ^[1-9][0-9]*$ ]] || (( DURATION_SECS < 60 || DURATION_SECS > 86400 )); then
    echo "Usage: bash run.sh [duration_secs 60-86400] [worker_name]" >&2
    exit 2
fi

current_status="$(bash "${SCRIPT_DIR}/status.sh")"
if grep -q '^STATUS=RUNNING$' <<< "$current_status"; then
    printf '%s\n' "$current_status"
    echo "Error: miner sudah berjalan; gunakan status.sh atau stop.sh." >&2
    exit 4
fi

mkdir -p "$BASE_DIR"
launch_env=("DURATION_SECS=${DURATION_SECS}")
if [[ -n "$WORKER_OVERRIDE" ]]; then
    launch_env+=("WORKER_NAME=${WORKER_OVERRIDE}")
fi

nohup env "${launch_env[@]}" bash "${SCRIPT_DIR}/start-miner.sh" \
    > "$LAUNCHER_LOG" 2>&1 < /dev/null &
launcher_pid=$!
printf '%s\n' "$launcher_pid" > "$LAUNCHER_PID_FILE"

echo "Launcher PID : ${launcher_pid}"
echo "Duration     : ${DURATION_SECS}s"
echo "Menunggu miner aktif dan accepted share..."

last_status=""
for attempt in {1..36}; do
    sleep 5
    last_status="$(bash "${SCRIPT_DIR}/status.sh")"
    if grep -q '^STATUS=RUNNING$' <<< "$last_status" &&
        grep -q '^ACCEPTED=[1-9][0-9]*$' <<< "$last_status"; then
        printf '%s\n' "$last_status"
        echo "STATUS=RUNNING_AND_ACCEPTED"
        exit 0
    fi

    if (( attempt % 2 == 0 )); then
        if grep -q '^STATUS=RUNNING$' <<< "$last_status"; then
            state="RUNNING"
        else
            state="STARTING"
        fi
        printf '[%3ss] %s\n' "$((attempt * 5))" "$state"
    fi

    if ! kill -0 "$launcher_pid" 2>/dev/null &&
        ! grep -q '^STATUS=RUNNING$' <<< "$last_status"; then
        tail -n 120 "$LAUNCHER_LOG" 2>/dev/null || true
        echo "Error: launcher berhenti sebelum miner aktif." >&2
        exit 6
    fi
done

printf '%s\n' "$last_status"
if grep -q '^STATUS=RUNNING$' <<< "$last_status"; then
    echo "Peringatan: miner hidup tetapi belum ada accepted share dalam 180 detik." >&2
    exit 0
fi

tail -n 120 "$LAUNCHER_LOG" 2>/dev/null || true
echo "Error: miner tidak aktif setelah 180 detik." >&2
exit 6

