#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
binary_exists headscale && { ok "Headscale already installed."; exit 0; }

if is_dry_run; then
  log "Would resolve the latest Headscale release, try the official DEB package, then the standalone binary."
  exit 0
fi

require_cmd curl
arch="$(detect_arch)"
release_json="$(curl -fsSL --retry 2 --connect-timeout 8 --max-time 30 https://api.github.com/repos/juanfont/headscale/releases/latest || true)"
tag="$(printf '%s' "$release_json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[[ -n "$tag" ]] || die "Could not resolve latest Headscale release."
version="${tag#v}"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir:-}"' EXIT

if command -v apt-get >/dev/null 2>&1; then
  deb="headscale_${version}_linux_${arch}.deb"
  deb_url="https://github.com/juanfont/headscale/releases/download/${tag}/${deb}"
  log "Trying Headscale DEB: ${deb_url}"
  if curl -fL --retry 2 --connect-timeout 8 --max-time 120 "$deb_url" -o "${workdir}/${deb}"; then
    if sudo_cmd apt-get install -y "${workdir}/${deb}" && binary_exists headscale; then
      ok "Headscale installed from official DEB package."
      exit 0
    fi
  fi
  warn "Headscale DEB route failed; trying standalone binary."
fi

binary="headscale_${version}_linux_${arch}"
binary_url="https://github.com/juanfont/headscale/releases/download/${tag}/${binary}"
log "Trying Headscale standalone binary: ${binary_url}"
if curl -fL --retry 2 --connect-timeout 8 --max-time 120 "$binary_url" -o "${workdir}/headscale"; then
  chmod 0755 "${workdir}/headscale"
  if [[ "${EUID}" -eq 0 ]]; then
    install -m 0755 "${workdir}/headscale" /usr/local/bin/headscale
  elif command -v sudo >/dev/null 2>&1; then
    sudo install -m 0755 "${workdir}/headscale" /usr/local/bin/headscale
  else
    mkdir -p "${HOME}/.local/bin"
    install -m 0755 "${workdir}/headscale" "${HOME}/.local/bin/headscale"
  fi
  binary_exists headscale && { ok "Headscale installed from official standalone binary."; exit 0; }
fi

die "Could not install Headscale from the official DEB package or standalone binary."
