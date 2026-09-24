#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${AGENT_PILOT_ROOT:?}"; source "${ROOT}/scripts/lib/common.sh"; require_linux
command -v qwen >/dev/null 2>&1 && { ok "Qwen Code already installed."; exit 0; }
run_downloaded_script "https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh"; ok "Qwen Code installed. Model setup is left to the user."
