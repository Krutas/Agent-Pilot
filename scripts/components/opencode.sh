#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v opencode >/dev/null 2>&1 && { ok "OpenCode already installed."; exit 0; }
run_downloaded_script "https://opencode.ai/install"; ok "OpenCode installer finished."
