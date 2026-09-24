#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v cline >/dev/null 2>&1 && { ok "Cline already installed."; exit 0; }
require_cmd npm; run npm install -g cline; ok "Cline CLI installed. Model setup is left to the user."
