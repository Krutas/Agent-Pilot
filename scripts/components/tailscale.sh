#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux

if ! binary_exists tailscale; then
  if try_downloaded_script "https://tailscale.com/install.sh" && binary_exists tailscale; then
    ok "Tailscale installed with official installer."
  else
    warn "Tailscale installer URL failed; trying configured system package manager."
    try_system_package "tailscale" "tailscale" || die "Could not install Tailscale via installer URL or system package manager."
  fi
else
  ok "Tailscale already installed."
fi

ARGS=(up)
[[ -n "${HEADSCALE_URL:-}" ]] && ARGS+=(--login-server "${HEADSCALE_URL}")
AUTH_KEY="${TAILSCALE_AUTH_KEY:-${HEADSCALE_PREAUTH_KEY:-}}"; [[ -n "$AUTH_KEY" ]] && ARGS+=(--auth-key "$AUTH_KEY")
[[ -n "${TAILSCALE_HOSTNAME:-}" ]] && ARGS+=(--hostname "${TAILSCALE_HOSTNAME}")
[[ -n "${TAILSCALE_TAGS:-}" ]] && ARGS+=(--advertise-tags "${TAILSCALE_TAGS}")
sudo_cmd tailscale "${ARGS[@]}"
ok "Tailscale node configured."
