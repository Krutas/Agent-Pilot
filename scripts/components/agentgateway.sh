#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
IMAGE="${AGENTGATEWAY_IMAGE:-cr.agentgateway.dev/agentgateway:v1.5.0}"; PORT="${AGENTGATEWAY_PORT:-4000}"; CONFIG_DIR="${AGENTGATEWAY_CONFIG_DIR:-/opt/agent-pilot/agentgateway-config}"
if command -v docker >/dev/null 2>&1; then ENGINE=docker; elif command -v podman >/dev/null 2>&1; then ENGINE=podman; else die "AgentGateway requires Docker or Podman."; fi
sudo_cmd mkdir -p "$CONFIG_DIR"; run "$ENGINE" pull "$IMAGE"; run "$ENGINE" rm -f agentgateway 2>/dev/null || true; run "$ENGINE" run -d --name agentgateway --restart unless-stopped -p "${PORT}:4000" -v "${CONFIG_DIR}:/config" "$IMAGE"; ok "AgentGateway started on port ${PORT}."
