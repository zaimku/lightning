#!/usr/bin/env bash
# Bootstrap Pearl/PRL miner inside an active Nosana PyTorch/Jupyter container.
set -Eeuo pipefail

readonly REPO_RAW_URL="https://raw.githubusercontent.com/zaimku/lightning/main"
INSTALL_DIR="${INSTALL_DIR:-/workspace/lightning}"
DURATION_SECS="${DURATION_SECS:-21600}"
WORKER_NAME="${WORKER_NAME:-nosana4090}"

command -v curl >/dev/null 2>&1 || {
    echo "Error: curl tidak tersedia pada container Nosana." >&2
    exit 3
}
command -v bash >/dev/null 2>&1 || {
    echo "Error: bash tidak tersedia pada container Nosana." >&2
    exit 3
}

mkdir -p "$INSTALL_DIR"
for filename in run.sh start-miner.sh status.sh stop.sh; do
    temporary_file="${INSTALL_DIR}/${filename}.part"
    echo "Mengunduh ${filename}..."
    curl -fL --retry 2 --connect-timeout 20 --max-time 120 \
        -o "$temporary_file" "${REPO_RAW_URL}/${filename}"
    [[ -s "$temporary_file" ]] || {
        echo "Error: ${filename} kosong setelah diunduh." >&2
        exit 5
    }
    mv -f "$temporary_file" "${INSTALL_DIR}/${filename}"
done

chmod 0755 "$INSTALL_DIR"/*.sh
cd "$INSTALL_DIR"
exec bash run.sh "$DURATION_SECS" "$WORKER_NAME"
