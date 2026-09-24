#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
binary_exists aider && { ok "Aider already installed."; exit 0; }

if try_downloaded_script "https://aider.chat/install.sh" && binary_exists aider; then
  ok "Aider installed with official installer."
  exit 0
fi
warn "Aider installer URL failed; trying Python package channels."

if try_python_tool "aider-chat" "aider"; then
  ok "Aider installed via uv/pipx/pip fallback."
  exit 0
fi

die "Could not install Aider via installer URL or Python package channels."
