#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
IMAGE="${AGENTGATEWAY_IMAGE:-cr.agentgateway.dev/agentgateway:v1.5.0}"
PORT="${AGENTGATEWAY_PORT:-4000}"
CONFIG_DIR="${AGENTGATEWAY_CONFIG_DIR:-/opt/agent-pilot/agentgateway-config}"

if command -v docker >/dev/null 2>&1; then ENGINE=docker
elif command -v podman >/dev/null 2>&1; then ENGINE=podman
else ENGINE=""
fi

if [[ -n "$ENGINE" ]]; then
  log "Trying AgentGateway container image: $IMAGE"
  if "$ENGINE" pull "$IMAGE"; then
    sudo_cmd mkdir -p "$CONFIG_DIR"
    "$ENGINE" rm -f agentgateway >/dev/null 2>&1 || true
    "$ENGINE" run -d --name agentgateway --restart unless-stopped -p "${PORT}:4000" -v "${CONFIG_DIR}:/config" "$IMAGE"
    ok "AgentGateway started with $ENGINE on port ${PORT}."
    exit 0
  fi
  warn "Container image route failed; trying official standalone installer."
fi

if try_downloaded_script "https://agentgateway.dev/install" && binary_exists agentgateway; then
  log "Starting standalone AgentGateway binary."
  mkdir -p "${HOME}/.local/state/agent-pilot"
  nohup agentgateway >"${HOME}/.local/state/agent-pilot/agentgateway.log" 2>&1 &
  sleep 2
  ok "AgentGateway installed via official binary fallback; startup log: ~/.local/state/agent-pilot/agentgateway.log"
  exit 0
fi

die "Could not install AgentGateway via container image or official standalone installer."
