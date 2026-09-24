#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
binary_exists cline && { ok "Cline already installed."; exit 0; }

if try_node_global "cline" "cline"; then
  ok "Cline CLI installed via available Node package manager."
  exit 0
fi

die "Could not install Cline with npm, pnpm, yarn, or bun."
