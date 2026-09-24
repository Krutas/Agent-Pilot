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
download_script(){ local url="$1" target="$2"; require_cmd curl; log "Download source: ${url}"; if is_dry_run; then printf '[dry-run] curl -fL --proto =https --tlsv1.2 %q -o %q\n' "$url" "$target"; else curl -fL --proto '=https' --tlsv1.2 "$url" -o "$target"; chmod 0700 "$target"; fi; }
run_downloaded_script(){ local url="$1"; shift; local temp; temp="$(mktemp)"; trap 'rm -f "${temp:-}"' RETURN; download_script "$url" "$temp"; run bash "$temp" "$@"; }
detect_arch(){ case "$(uname -m)" in x86_64|amd64) echo amd64;; aarch64|arm64) echo arm64;; *) die "Unsupported architecture: $(uname -m)";; esac; }
