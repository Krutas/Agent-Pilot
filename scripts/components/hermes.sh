#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v hermes >/dev/null 2>&1 && { ok "Hermes already installed."; exit 0; }
run_downloaded_script "https://hermes-agent.nousresearch.com/install.sh"; ok "Hermes installer finished."
