#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
binary_exists agent-canvas && { ok "OpenHands Agent Canvas already installed."; exit 0; }

if try_node_global "@openhands/agent-canvas" "agent-canvas"; then
  ok "OpenHands Agent Canvas installed via available Node package manager."
  exit 0
fi

die "Could not install OpenHands Agent Canvas with npm, pnpm, yarn, or bun."
