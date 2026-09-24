#!/usr/bin/env bash
set -Eeuo pipefail

log(){ printf '\033[1;34m[agent-pilot]\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32m[ok]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

is_dry_run(){ [[ "${AGENT_PILOT_DRY_RUN:-false}" == "true" ]]; }
run(){ if is_dry_run; then printf '[dry-run] '; printf '%q ' "$@"; printf '\n'; else "$@"; fi; }
require_linux(){ [[ "$(uname -s)" == "Linux" ]] || die "MVP currently supports Linux/WSL2."; }
require_cmd(){ command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
sudo_cmd(){ if [[ "${EUID}" -eq 0 ]]; then run "$@"; else require_cmd sudo; run sudo "$@"; fi; }
binary_exists(){ command -v "$1" >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/$1" ]]; }

download_script(){
  local url="$1" target="$2"
  require_cmd curl
  log "Download source: ${url}"
  if is_dry_run; then
    printf '[dry-run] curl -fL --retry 2 --connect-timeout 8 --max-time 90 --proto =https --tlsv1.2 %q -o %q\n' "$url" "$target"
  else
    curl -fL --retry 2 --retry-delay 1 --connect-timeout 8 --max-time 90 --proto '=https' --tlsv1.2 "$url" -o "$target"
    chmod 0700 "$target"
  fi
}

run_downloaded_script(){
  local url="$1"; shift
  local temp; temp="$(mktemp)"
  trap 'rm -f "${temp:-}"' RETURN
  download_script "$url" "$temp"
  run bash "$temp" "$@"
}

try_downloaded_script(){
  local url="$1"; shift
  local temp rc
  if is_dry_run; then
    log "Would try installer URL: ${url}"
    return 0
  fi
  command -v curl >/dev/null 2>&1 || return 1
  temp="$(mktemp)"
  log "Trying installer URL: ${url}"
  if ! curl -fL --retry 2 --retry-delay 1 --connect-timeout 8 --max-time 90 --proto '=https' --tlsv1.2 "$url" -o "$temp"; then
    rm -f "$temp"
    return 1
  fi
  chmod 0700 "$temp"
  if bash "$temp" "$@"; then rc=0; else rc=$?; fi
  rm -f "$temp"
  return "$rc"
}

try_node_global(){
  local package="$1" binary="$2" manager
  if is_dry_run; then
    log "Would try Node package managers for ${package}: npm, pnpm, yarn, bun"
    return 0
  fi
  for manager in npm pnpm yarn bun; do
    command -v "$manager" >/dev/null 2>&1 || continue
    log "Trying ${manager} fallback for ${package}"
    case "$manager" in
      npm) npm install -g "$package" || continue ;;
      pnpm) pnpm add -g "$package" || continue ;;
      yarn) yarn global add "$package" || continue ;;
      bun) bun install -g "$package" || continue ;;
    esac
    binary_exists "$binary" && return 0
  done
  return 1
}

try_python_tool(){
  local package="$1" binary="$2"
  if is_dry_run; then
    log "Would try Python tool installers for ${package}: uv, pipx, pip"
    return 0
  fi
  if command -v uv >/dev/null 2>&1; then
    log "Trying uv fallback for ${package}"
    uv tool install --force "$package" && binary_exists "$binary" && return 0
  fi
  if command -v pipx >/dev/null 2>&1; then
    log "Trying pipx fallback for ${package}"
    pipx install --force "$package" && binary_exists "$binary" && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    log "Trying pip fallback for ${package}"
    python3 -m pip install --user -U "$package" && binary_exists "$binary" && return 0
  fi
  return 1
}

try_brew(){
  local formula="$1" binary="$2"
  if is_dry_run; then log "Would try Homebrew formula: ${formula}"; return 0; fi
  command -v brew >/dev/null 2>&1 || return 1
  log "Trying Homebrew fallback: ${formula}"
  brew install "$formula" && binary_exists "$binary"
}

try_system_package(){
  local package="$1" binary="$2"
  if is_dry_run; then log "Would try system package manager for ${package}"; return 0; fi
  if command -v apt-get >/dev/null 2>&1; then
    sudo_cmd apt-get update && sudo_cmd apt-get install -y "$package" && binary_exists "$binary" && return 0
  elif command -v dnf >/dev/null 2>&1; then
    sudo_cmd dnf install -y "$package" && binary_exists "$binary" && return 0
  elif command -v yum >/dev/null 2>&1; then
    sudo_cmd yum install -y "$package" && binary_exists "$binary" && return 0
  elif command -v zypper >/dev/null 2>&1; then
    sudo_cmd zypper --non-interactive install "$package" && binary_exists "$binary" && return 0
  elif command -v pacman >/dev/null 2>&1; then
    sudo_cmd pacman -S --noconfirm "$package" && binary_exists "$binary" && return 0
  fi
  return 1
}

detect_arch(){ case "$(uname -m)" in x86_64|amd64) echo amd64;; aarch64|arm64) echo arm64;; *) die "Unsupported architecture: $(uname -m)";; esac; }
