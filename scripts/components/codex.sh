#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v codex >/dev/null 2>&1 && { ok "Codex CLI already installed."; exit 0; }
run_downloaded_script "https://chatgpt.com/codex/install.sh"; ok "Codex CLI installer finished."
