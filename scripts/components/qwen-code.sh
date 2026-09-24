#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
binary_exists qwen && { ok "Qwen Code already installed."; exit 0; }

if try_downloaded_script "https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh" && binary_exists qwen; then
  ok "Qwen Code installed with standalone installer."
  exit 0
fi
warn "Qwen standalone installer failed; trying package-manager routes."

if try_node_global "@qwen-code/qwen-code@latest" "qwen"; then
  ok "Qwen Code installed via Node package-manager fallback."
  exit 0
fi

if try_brew "qwen-code" "qwen"; then
  ok "Qwen Code installed via Homebrew fallback."
  exit 0
fi

die "Could not install Qwen Code via standalone installer, Node package managers, or Homebrew."
