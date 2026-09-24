#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
if ! command -v tailscale >/dev/null 2>&1; then run_downloaded_script "https://tailscale.com/install.sh"; else ok "Tailscale already installed."; fi
ARGS=(up)
[[ -n "${HEADSCALE_URL:-}" ]] && ARGS+=(--login-server "${HEADSCALE_URL}")
AUTH_KEY="${TAILSCALE_AUTH_KEY:-${HEADSCALE_PREAUTH_KEY:-}}"; [[ -n "$AUTH_KEY" ]] && ARGS+=(--auth-key "$AUTH_KEY")
[[ -n "${TAILSCALE_HOSTNAME:-}" ]] && ARGS+=(--hostname "${TAILSCALE_HOSTNAME}")
[[ -n "${TAILSCALE_TAGS:-}" ]] && ARGS+=(--advertise-tags "${TAILSCALE_TAGS}")
sudo_cmd tailscale "${ARGS[@]}"; ok "Tailscale node configured."
