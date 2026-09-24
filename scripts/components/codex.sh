#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v codex >/dev/null 2>&1 && { ok "Codex CLI already installed."; exit 0; }

PRIMARY_URL="https://chatgpt.com/codex/install.sh"

codex_visible() {
  command -v codex >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/codex" ]]
}

if is_dry_run; then
  log "Would try official Codex standalone installer: ${PRIMARY_URL}"
  log "Would force that installer to use GitHub Releases instead of releases.openai.com."
  log "Would fall back to the latest official GitHub Release binary, then @openai/codex via npm."
  exit 0
fi

# Route 1: official standalone bootstrap. Force GitHub Releases internally so
# releases.openai.com is not another single point of failure.
if command -v curl >/dev/null 2>&1; then
  temp="$(mktemp)"
  trap 'rm -f "${temp:-}"' EXIT
  log "Trying official Codex installer: ${PRIMARY_URL}"
  if curl -fL --retry 2 --retry-delay 1 --connect-timeout 8 --max-time 45 \
      --proto '=https' --tlsv1.2 "$PRIMARY_URL" -o "$temp"; then
    chmod 0700 "$temp"
    if CODEX_INSTALLER_USE_RELEASES_OPENAI_COM=false CODEX_NON_INTERACTIVE=1 bash "$temp"; then
      if codex_visible; then
        ok "Codex CLI installed with the official standalone installer."
        exit 0
      fi
    fi
  fi
  warn "Standalone Codex installer did not complete; trying direct GitHub Release."
else
  warn "curl is unavailable; skipping standalone and direct-release Codex methods."
fi

# Route 2: latest official GitHub Release binary. This path bypasses chatgpt.com
# completely and does not require Node.js/npm.
if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
  case "$(uname -m)" in
    x86_64|amd64) target="x86_64-unknown-linux-musl" ;;
    aarch64|arm64) target="aarch64-unknown-linux-musl" ;;
    *) target="" ;;
  esac

  if [[ -n "$target" ]]; then
    workdir="$(mktemp -d)"
    trap 'rm -rf "${workdir:-}" "${temp:-}"' EXIT
    asset="codex-${target}.tar.gz"
    release_url="https://github.com/openai/codex/releases/latest/download/${asset}"
    log "Trying official Codex GitHub Release: ${release_url}"
    if curl -fL --retry 2 --retry-delay 1 --connect-timeout 8 --max-time 180 \
        --proto '=https' --tlsv1.2 "$release_url" -o "${workdir}/${asset}"; then
      if tar -xzf "${workdir}/${asset}" -C "$workdir"; then
        binary="$(find "$workdir" -maxdepth 2 -type f -name 'codex*' ! -name '*.tar.gz' | head -n 1 || true)"
        if [[ -n "$binary" ]]; then
          mkdir -p "${HOME}/.local/bin"
          install -m 0755 "$binary" "${HOME}/.local/bin/codex"
          if codex_visible; then
            ok "Codex CLI installed from the official GitHub Release."
            exit 0
          fi
        fi
      fi
    fi
    warn "Direct GitHub Release install failed; trying npm fallback."
  else
    warn "Unsupported architecture for direct Codex release; trying npm fallback."
  fi
fi

# Route 3: official npm package.
if command -v npm >/dev/null 2>&1; then
  run npm install -g @openai/codex
  if codex_visible; then
    ok "Codex CLI installed via @openai/codex npm fallback."
    exit 0
  fi
  die "npm finished but Codex is not available on PATH or ~/.local/bin."
fi

die "Could not install Codex using the standalone installer, GitHub Release, or npm fallback. Check network access to chatgpt.com/github.com or install npm and retry."
