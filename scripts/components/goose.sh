#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v goose >/dev/null 2>&1 && { ok "goose already installed."; exit 0; }
run_downloaded_script "https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh"; ok "goose installer finished. Model setup is left to the user."
