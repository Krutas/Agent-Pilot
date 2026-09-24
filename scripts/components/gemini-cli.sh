#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
binary_exists gemini && { ok "Gemini CLI already installed."; exit 0; }

if try_node_global "@google/gemini-cli@latest" "gemini"; then
  ok "Gemini CLI installed via Node package manager."
  exit 0
fi
warn "Node package-manager routes failed; trying Homebrew."

if try_brew "gemini-cli" "gemini"; then
  ok "Gemini CLI installed via Homebrew fallback."
  exit 0
fi

die "Could not install Gemini CLI via Node package managers or Homebrew."
