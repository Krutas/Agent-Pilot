#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v gemini >/dev/null 2>&1 && { ok "Gemini CLI already installed."; exit 0; }
require_cmd npm; run npm install -g @google/gemini-cli; ok "Gemini CLI installed. Model setup is left to the user."
