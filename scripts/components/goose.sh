#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
binary_exists goose && { ok "goose already installed."; exit 0; }

if try_downloaded_script "https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh" && binary_exists goose; then
  ok "goose installed with official release installer."
  exit 0
fi
warn "goose release installer failed; trying Homebrew."

if try_brew "block-goose-cli" "goose"; then
  ok "goose installed via Homebrew fallback."
  exit 0
fi

die "Could not install goose via release installer or Homebrew."
