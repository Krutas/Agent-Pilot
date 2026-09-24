#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
if command -v headscale >/dev/null 2>&1; then ok "Headscale already installed."; exit 0; fi
if is_dry_run; then log "Would resolve latest Headscale release from https://github.com/juanfont/headscale/releases"; exit 0; fi
die "Headscale automatic package resolution is not yet hardened. Install from the official release page, then rerun Agent Pilot health checks."
