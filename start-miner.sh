#!/usr/bin/env bash
# Lightning AI Studio raw NVIDIA GPU -> Pearl/HeroMiners.
set -Eeuo pipefail

DURATION_SECS="${1:-${DURATION_SECS:-86400}}"
PEAKMINER_VERSION="${PEAKMINER_VERSION:-2.14.0}"
PEAKMINER_SHA256="${PEAKMINER_SHA256:-8c03a1f790a54dd05d5ca75e8bfb3b1a8c3e7db24fd2a33f43c8b38bbf164646}"
PEAKMINER_URL="${PEAKMINER_URL:-https://github.com/peakminer/peakminer/releases/download/v${PEAKMINER_VERSION}/peakminer-${PEAKMINER_VERSION}-linux-x86_64}"
PEAKMINER_MIRROR_URL="${PEAKMINER_MIRROR_URL:-https://gh-proxy.com/${PEAKMINER_URL}}"

PEARL_WALLET="${PEARL_WALLET:-prl1pazsjqnmy58svgf7e85n0e2quxtj3f698q5f3p34grtnsf0t2jp7q2ynx3s}"
WORKER_NAME="${WORKER_NAME:-lightning$((RANDOM % 1000000))}"
GPU_POWER_LIMIT="${GPU_POWER_LIMIT:-}"
LOG_TO_STDOUT="${LOG_TO_STDOUT:-0}"
POOL_ENDPOINTS="${POOL_ENDPOINTS:-us2.pearl.herominers.com:1200,us.pearl.herominers.com:1200,sg.pearl.herominers.com:1200,hk.pearl.herominers.com:1200,de.pearl.herominers.com:1200}"

BASE_DIR="${BASE_DIR:-${HOME}/lightning-herominers}"
BIN_DIR="${BIN_DIR:-${BASE_DIR}/bin}"
LOG_DIR="${LOG_DIR:-${BASE_DIR}/logs}"
MINER_BIN="${MINER_BIN:-${BIN_DIR}/peakminer-${PEAKMINER_VERSION}}"
PID_FILE="${BASE_DIR}/miner.pid"
LAUNCHER_PID_FILE="${BASE_DIR}/launcher.pid"
SESSION_FILE="${BASE_DIR}/current-session.env"
CURRENT_LOG_LINK="${BASE_DIR}/current.log"

if ! [[ "$DURATION_SECS" =~ ^(0|[1-9][0-9]*)$ ]] ||
    (( DURATION_SECS != 0 && (DURATION_SECS < 60 || DURATION_SECS > 86400) )); then
    echo "Error: durasi harus 0 (tanpa batas) atau 60-86400 detik." >&2
    exit 2
fi

# Optional cap as a percentage of the GPU's default power, not utilization.
if [[ -n "$GPU_POWER_LIMIT" ]] && ! [[ "$GPU_POWER_LIMIT" =~ ^([1-9][0-9]?|100)%$ ]]; then
    echo "Error: GPU_POWER_LIMIT harus 1%-100%, misalnya 85%. Kosong berarti tanpa batas tambahan." >&2
    exit 2
fi

if [[ "$LOG_TO_STDOUT" != 0 && "$LOG_TO_STDOUT" != 1 ]]; then
    echo "Error: LOG_TO_STDOUT harus 0 atau 1." >&2
    exit 2
fi

if ! [[ "$PEARL_WALLET" =~ ^prl1[a-z0-9]{20,100}$ ]]; then
    echo "Error: wallet Pearl tidak valid." >&2
    exit 2
fi

if ! [[ "$WORKER_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
    echo "Error: nama worker tidak valid." >&2
    exit 2
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "Error: binary PeakMiner ini membutuhkan Linux x86_64." >&2
    exit 3
fi

for required_command in nvidia-smi sha256sum grep timeout pgrep; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "Error: command '$required_command' tidak tersedia di Studio." >&2
        exit 3
    fi
done
if ! command -v curl >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    echo "Error: unduhan membutuhkan curl atau python3." >&2
    exit 3
fi
if [[ "$LOG_TO_STDOUT" == 1 ]] && ! command -v tee >/dev/null 2>&1; then
    echo "Error: command 'tee' diperlukan saat LOG_TO_STDOUT=1." >&2
    exit 3
fi

mkdir -p "$BASE_DIR" "$BIN_DIR" "$LOG_DIR"

existing_pid=""
if [[ -f "$PID_FILE" ]]; then
    existing_pid="$(tr -dc '0-9' < "$PID_FILE")"
fi
if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    echo "Error: miner sudah berjalan dengan PID ${existing_pid}." >&2
    exit 4
fi

fallback_pid="$(pgrep -o -f "^${BIN_DIR}/peakminer-${PEAKMINER_VERSION} --coin pearl" || true)"
if [[ -n "$fallback_pid" ]]; then
    echo "Error: PeakMiner Pearl sudah berjalan dengan PID ${fallback_pid}." >&2
    exit 4
fi

echo "=== Lightning AI HeroMiners preflight ==="
gpu_rows="$(nvidia-smi --query-gpu=index,name,compute_cap,driver_version,memory.total --format=csv,noheader 2>/dev/null || true)"
if [[ -z "$gpu_rows" ]]; then
    echo "Error: GPU NVIDIA tidak terdeteksi. Switch Studio ke mesin GPU terlebih dahulu." >&2
    exit 3
fi
printf '%s\n' "$gpu_rows"

while IFS=',' read -r gpu_index gpu_name gpu_capability _; do
    gpu_name="${gpu_name# }"
    gpu_capability="${gpu_capability//[[:space:]]/}"
    capability_major="${gpu_capability%%.*}"
    if ! [[ "$capability_major" =~ ^[0-9]+$ ]] || (( capability_major < 8 )); then
        echo "Error: GPU ${gpu_index} (${gpu_name}, sm_${gpu_capability}) tidak didukung untuk workload Pearl ini." >&2
        echo "Pilih L4, A10, RTX 30/40, A100, H100/H200, B200, atau GPU sm_80+." >&2
        exit 3
    fi
done <<< "$gpu_rows"

library_has_required_symbol() {
    local library_path="$1"
    [[ -f "$library_path" ]] && grep -a -q 'GLIBCXX_3.4.29' "$library_path"
}

cpp_candidates=(
    /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    /usr/local/lib/libstdc++.so.6
    /opt/conda/lib/libstdc++.so.6
    "${HOME}/miniconda3/lib/libstdc++.so.6"
)
if [[ -n "${CONDA_PREFIX:-}" ]]; then
    cpp_candidates+=("${CONDA_PREFIX}/lib/libstdc++.so.6")
fi

compatible_cpp_library=""
for candidate in "${cpp_candidates[@]}"; do
    if library_has_required_symbol "$candidate"; then
        compatible_cpp_library="$candidate"
        break
    fi
done

if [[ -z "$compatible_cpp_library" ]]; then
    echo "Error: libstdc++ dengan GLIBCXX_3.4.29 tidak ditemukan." >&2
    echo "Gunakan Base Studio Linux yang lebih baru atau perbarui paket libstdc++6." >&2
    exit 3
fi

cpp_dir="$(dirname "$compatible_cpp_library")"
export LD_LIBRARY_PATH="${cpp_dir}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
if [[ "$compatible_cpp_library" != "/usr/lib/x86_64-linux-gnu/libstdc++.so.6" ]]; then
    echo "Memakai libstdc++ kompatibel dari ${cpp_dir}."
fi

binary_is_valid() {
    [[ -x "$MINER_BIN" ]] &&
        printf '%s  %s\n' "$PEAKMINER_SHA256" "$MINER_BIN" | sha256sum -c - >/dev/null 2>&1
}

download_file() {
    local source_url="$1"
    local destination="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 2 --retry-max-time 180 --connect-timeout 20 --max-time 240 \
            --speed-limit 65536 --speed-time 20 -o "$destination" "$source_url"
        return
    fi

    python3 - "$source_url" "$destination" <<'PY'
import pathlib
import sys
import time
import urllib.request

source_url, destination = sys.argv[1:3]
target = pathlib.Path(destination)
last_error = None
for attempt in range(3):
    try:
        request = urllib.request.Request(source_url, headers={"User-Agent": "pearl-nosana-runner"})
        with urllib.request.urlopen(request, timeout=240) as response, target.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
        raise SystemExit(0)
    except Exception as exc:
        last_error = exc
        target.unlink(missing_ok=True)
        if attempt < 2:
            time.sleep(2)
print(f"download failed: {last_error}", file=sys.stderr)
raise SystemExit(1)
PY
}

download_path="${MINER_BIN}.part"
if ! binary_is_valid; then
    download_ok=false
    for download_url in "$PEAKMINER_URL" "$PEAKMINER_MIRROR_URL"; do
        rm -f "$download_path"
        echo "Mengunduh PeakMiner v${PEAKMINER_VERSION} dari ${download_url}"
        if download_file "$download_url" "$download_path" &&
            printf '%s  %s\n' "$PEAKMINER_SHA256" "$download_path" | sha256sum -c -; then
            download_ok=true
            break
        fi
        echo "Download gagal/lambat atau checksum salah; mencoba sumber berikutnya." >&2
    done
    if [[ "$download_ok" != true ]]; then
        rm -f "$download_path"
        echo "Error: PeakMiner tidak dapat diunduh dan diverifikasi." >&2
        exit 5
    fi
    chmod 0755 "$download_path"
    mv -f "$download_path" "$MINER_BIN"
fi

if [[ -n "$GPU_POWER_LIMIT" ]]; then
    miner_help="$("$MINER_BIN" --help 2>&1)" || {
        echo "Error: tidak dapat memeriksa dukungan batas daya PeakMiner." >&2
        exit 3
    }
    if ! grep -q -- '--gpu-power' <<< "$miner_help"; then
        echo "Error: versi PeakMiner ini tidak menyediakan --gpu-power." >&2
        exit 3
    fi
fi

IFS=',' read -r -a raw_endpoints <<< "$POOL_ENDPOINTS"
reachable_endpoints=()
for raw_endpoint in "${raw_endpoints[@]}"; do
    endpoint="${raw_endpoint//[[:space:]]/}"
    if ! [[ "$endpoint" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]]; then
        echo "Error: endpoint pool tidak valid: ${endpoint}" >&2
        exit 2
    fi
    host="${endpoint%:*}"
    port="${endpoint##*:}"
    if (( port < 1 || port > 65535 )); then
        echo "Error: port pool tidak valid: ${endpoint}" >&2
        exit 2
    fi
    if timeout 8 bash -c "exec 3<>/dev/tcp/${host}/${port}" 2>/dev/null; then
        reachable_endpoints+=("$endpoint")
    else
        echo "Peringatan: endpoint tidak dapat dijangkau dan dilewati: ${endpoint}" >&2
    fi
done

if (( ${#reachable_endpoints[@]} == 0 )); then
    echo "Error: tidak ada endpoint HeroMiners yang dapat dijangkau dari Studio." >&2
    exit 6
fi

miner_command=(
    "$MINER_BIN"
    --coin pearl
    --user "${PEARL_WALLET}.${WORKER_NAME}"
    --api-port 0
)
for endpoint in "${reachable_endpoints[@]}"; do
    miner_command+=(--url "$endpoint")
done
if [[ -n "$GPU_POWER_LIMIT" ]]; then
    miner_command+=(--gpu-power "$GPU_POWER_LIMIT")
fi

started_at="$(date -u +%Y%m%dT%H%M%SZ)"
started_epoch="$(date +%s)"
if (( DURATION_SECS == 0 )); then
    ends_epoch=0
else
    ends_epoch="$((started_epoch + DURATION_SECS))"
fi
log_file="${LOG_DIR}/${WORKER_NAME}-${started_at}.log"
ln -sfn "$log_file" "$CURRENT_LOG_LINK"

cat > "$SESSION_FILE" <<EOF
WORKER_NAME=${WORKER_NAME}
GPU_POWER_LIMIT_REQUESTED=${GPU_POWER_LIMIT:-unset}
POOL_ENDPOINTS=$(IFS=,; echo "${reachable_endpoints[*]}")
LOG_FILE=${log_file}
STARTED_AT_UTC=${started_at}
DURATION_SECS=${DURATION_SECS}
ENDS_EPOCH=${ends_epoch}
EOF

echo "Worker      : ${WORKER_NAME}"
echo "Pools       : $(IFS=,; echo "${reachable_endpoints[*]}")"
if (( DURATION_SECS == 0 )); then
    echo "Duration    : tanpa batas (sampai dihentikan/container berhenti)"
else
    echo "Duration    : ${DURATION_SECS}s"
fi
if [[ -n "$GPU_POWER_LIMIT" ]]; then
    echo "Power request: ${GPU_POWER_LIMIT} dari daya default; bukan batas utilisasi/core."
    echo "Penerapan memerlukan izin driver. Cek power.limit di status.sh dan pesan error pada log."
fi
echo "Log         : ${log_file}"

if [[ "$LOG_TO_STDOUT" == 1 ]]; then
    "${miner_command[@]}" > >(tee -a "$log_file") 2>&1 &
else
    "${miner_command[@]}" >> "$log_file" 2>&1 &
fi
miner_pid=$!
printf '%s\n' "$miner_pid" > "$PID_FILE"

terminate_miner() {
    if kill -0 "$miner_pid" 2>/dev/null; then
        kill -TERM "$miner_pid" 2>/dev/null || true
        for _ in {1..15}; do
            if ! kill -0 "$miner_pid" 2>/dev/null; then
                return
            fi
            sleep 1
        done
        kill -KILL "$miner_pid" 2>/dev/null || true
    fi
}

cleanup_state() {
    current_pid="$(tr -dc '0-9' < "$PID_FILE" 2>/dev/null || true)"
    if [[ "$current_pid" == "$miner_pid" ]]; then
        rm -f "$PID_FILE"
    fi
    rm -f "$LAUNCHER_PID_FILE"
}

trap terminate_miner TERM INT
trap cleanup_state EXIT

while kill -0 "$miner_pid" 2>/dev/null; do
    if (( ends_epoch != 0 && $(date +%s) >= ends_epoch )); then
        echo "Durasi selesai; menghentikan miner."
        terminate_miner
        break
    fi
    sleep 5
done

set +e
wait "$miner_pid"
miner_exit_code=$?
set -e

if [[ "$miner_exit_code" -eq 0 || "$miner_exit_code" -eq 143 ]]; then
    echo "Sesi mining selesai; Studio dapat auto-sleep setelah workload berhenti."
    exit 0
fi

echo "PeakMiner berhenti dengan exit code ${miner_exit_code}." >&2
exit "$miner_exit_code"
