#!/usr/bin/env bash
# Bootstrap Pearl/PRL miner inside an active Nosana PyTorch/Jupyter container.
set -Eeuo pipefail

readonly REPO_RAW_URL="https://raw.githubusercontent.com/zaimku/lightning/main"
INSTALL_DIR="${INSTALL_DIR:-/workspace/lightning}"
DURATION_SECS="${DURATION_SECS:-21600}"
WORKER_NAME="${WORKER_NAME:-nosana4090}"

command -v bash >/dev/null 2>&1 || {
    echo "Error: bash tidak tersedia pada container Nosana." >&2
    exit 3
}
if ! command -v curl >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    echo "Error: bootstrap membutuhkan curl atau python3." >&2
    exit 3
fi

download_script() {
    local source_url="$1"
    local destination="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 2 --connect-timeout 20 --max-time 120 \
            -o "$destination" "$source_url"
    else
        python3 - "$source_url" "$destination" <<'PY'
import pathlib
import sys
import urllib.request

source_url, destination = sys.argv[1:3]
request = urllib.request.Request(source_url, headers={"User-Agent": "pearl-nosana-bootstrap"})
with urllib.request.urlopen(request, timeout=120) as response, pathlib.Path(destination).open("wb") as output:
    while chunk := response.read(1024 * 1024):
        output.write(chunk)
PY
    fi
}

mkdir -p "$INSTALL_DIR"
for filename in run.sh start-miner.sh status.sh stop.sh; do
    temporary_file="${INSTALL_DIR}/${filename}.part"
    echo "Mengunduh ${filename}..."
    download_script "${REPO_RAW_URL}/${filename}" "$temporary_file"
    [[ -s "$temporary_file" ]] || {
        echo "Error: ${filename} kosong setelah diunduh." >&2
        exit 5
    }
    mv -f "$temporary_file" "${INSTALL_DIR}/${filename}"
done

chmod 0755 "$INSTALL_DIR"/*.sh
cd "$INSTALL_DIR"
exec bash run.sh "$DURATION_SECS" "$WORKER_NAME"
