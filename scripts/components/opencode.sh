#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
binary_exists opencode && { ok "OpenCode already installed."; exit 0; }

if try_downloaded_script "https://opencode.ai/v2/install" && binary_exists opencode; then
  ok "OpenCode installed with official installer."
  exit 0
fi
warn "OpenCode installer URL failed; trying package-manager routes."

if try_node_global "@opencode/cli" "opencode"; then
  ok "OpenCode installed via Node package-manager fallback."
  exit 0
fi

if try_brew "anomalyco/tap/opencode-v2" "opencode"; then
  ok "OpenCode installed via Homebrew fallback."
  exit 0
fi

die "Could not install OpenCode via installer URL, Node package managers, or Homebrew."
