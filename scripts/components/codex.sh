#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v codex >/dev/null 2>&1 && { ok "Codex CLI already installed."; exit 0; }

PRIMARY_URL="https://chatgpt.com/codex/install.sh"

if is_dry_run; then
  log "Would try official Codex installer: ${PRIMARY_URL}"
  log "Would fall back to npm package @openai/codex if the installer is blocked or unavailable."
  exit 0
fi

if command -v curl >/dev/null 2>&1; then
  temp="$(mktemp)"
  trap 'rm -f "${temp:-}"' EXIT
  log "Trying official Codex installer: ${PRIMARY_URL}"
  if curl -fL --retry 2 --retry-delay 1 --connect-timeout 8 --max-time 45 \
      --proto '=https' --tlsv1.2 "$PRIMARY_URL" -o "$temp"; then
    chmod 0700 "$temp"
    if bash "$temp"; then
      command -v codex >/dev/null 2>&1 && { ok "Codex CLI installed with official installer."; exit 0; }
    fi
  fi
  warn "Official Codex installer did not complete; trying npm fallback."
else
  warn "curl is unavailable; trying npm fallback for Codex."
fi

if command -v npm >/dev/null 2>&1; then
  run npm install -g @openai/codex
  command -v codex >/dev/null 2>&1 || die "npm finished but 'codex' is not on PATH."
  ok "Codex CLI installed via @openai/codex npm fallback."
  exit 0
fi

die "Could not install Codex: official installer failed or was blocked, and npm is unavailable. Install Node.js/npm or retry from a network that can reach chatgpt.com."
