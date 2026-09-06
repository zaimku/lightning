#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="${BASE_DIR:-${HOME}/lightning-herominers}"
BIN_DIR="${BIN_DIR:-${BASE_DIR}/bin}"
LOG_DIR="${LOG_DIR:-${BASE_DIR}/logs}"
PID_FILE="${BASE_DIR}/miner.pid"
SESSION_FILE="${BASE_DIR}/current-session.env"
CURRENT_LOG_LINK="${BASE_DIR}/current.log"

pid=""
if [[ -f "$PID_FILE" ]]; then
    pid="$(tr -dc '0-9' < "$PID_FILE")"
fi
if { [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; } && command -v pgrep >/dev/null 2>&1; then
    pid="$(pgrep -o -f "^${BIN_DIR}/peakminer-[0-9.]+ --coin pearl" || true)"
fi

if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "STATUS=RUNNING"
    echo "PID=${pid}"
else
    echo "STATUS=STOPPED"
fi

if [[ -f "$SESSION_FILE" ]]; then
    cat "$SESSION_FILE"
fi

if command -v nvidia-smi >/dev/null 2>&1; then
    echo "GPU_STATUS"
    nvidia-smi --query-gpu=index,name,utilization.gpu,power.draw,memory.used,temperature.gpu \
        --format=csv,noheader 2>&1 || true
fi

log_file=""
if [[ -L "$CURRENT_LOG_LINK" || -f "$CURRENT_LOG_LINK" ]]; then
    log_file="$(readlink -f "$CURRENT_LOG_LINK" 2>/dev/null || true)"
fi
if [[ -z "$log_file" || ! -f "$log_file" ]]; then
    log_file="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'lightning*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2- || true)"
fi

if [[ -n "$log_file" && -f "$log_file" ]]; then
    echo "LOG_FILE=${log_file}"
    accepted_count="$(grep -c 'accepted' "$log_file" || true)"
    rejected_count="$(grep -c 'rejected' "$log_file" || true)"
    echo "ACCEPTED=${accepted_count}"
    echo "REJECTED=${rejected_count}"
    echo "RECENT_EVENTS"
    tail -n 120 "$log_file" |
        grep -E 'connected|vardiff|accepted|rejected|ERROR|WARN|new job|shutting down' |
        tail -n 40 || true
else
    echo "LOG_FILE=NONE"
    echo "ACCEPTED=0"
    echo "REJECTED=0"
fi
