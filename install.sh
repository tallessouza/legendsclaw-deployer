#!/usr/bin/env bash
# Wrapper — redireciona para deployer/install.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/deployer/install.sh" "$@"
