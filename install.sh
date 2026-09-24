#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
PYTHON_BIN="${PYTHON_BIN:-python3}"
command -v "${PYTHON_BIN}" >/dev/null 2>&1 || { echo "ERROR: python3 is required" >&2; exit 1; }
[[ -d "${VENV_DIR}" ]] || "${PYTHON_BIN}" -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/python" -m pip install --disable-pip-version-check -q -e "${ROOT_DIR}"
exec "${VENV_DIR}/bin/agent-pilot" "$@"
