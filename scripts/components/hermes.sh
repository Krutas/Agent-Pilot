#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
binary_exists hermes && { ok "Hermes already installed."; exit 0; }

if try_downloaded_script "https://hermes-agent.nousresearch.com/install.sh" && binary_exists hermes; then
  ok "Hermes installed with official installer."
  exit 0
fi
warn "Hermes installer URL failed; trying source installation."

if command -v git >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir:-}"' EXIT
  if git clone --depth 1 https://github.com/NousResearch/hermes-agent.git "${workdir}/hermes-agent"; then
    venv="${HOME}/.hermes/venvs/agent-pilot"
    python3 -m venv "$venv"
    "$venv/bin/python" -m pip install -U pip
    if "$venv/bin/pip" install "${workdir}/hermes-agent"; then
      mkdir -p "${HOME}/.local/bin"
      if [[ -x "$venv/bin/hermes" ]]; then
        ln -sf "$venv/bin/hermes" "${HOME}/.local/bin/hermes"
      fi
      binary_exists hermes && { ok "Hermes installed from official source repository fallback."; exit 0; }
    fi
  fi
fi

die "Could not install Hermes via official installer or source repository fallback."
