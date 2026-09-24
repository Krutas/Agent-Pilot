#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v agent-canvas >/dev/null 2>&1 && { ok "OpenHands Agent Canvas already installed."; exit 0; }
require_cmd npm; run npm install -g @openhands/agent-canvas; ok "OpenHands Agent Canvas installed."
