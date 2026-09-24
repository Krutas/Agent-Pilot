#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v aider >/dev/null 2>&1 && { ok "Aider already installed."; exit 0; }
require_cmd python3; run python3 -m pip install --user aider-install; run aider-install; ok "Aider installer finished."
