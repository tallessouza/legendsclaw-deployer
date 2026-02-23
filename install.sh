#!/usr/bin/env bash
# Wrapper — redireciona para deployer/install.sh
# Compativel com: bash <(curl ...), curl | bash, e execucao direta
set -eo pipefail

# Detectar se rodando via pipe/stdin (BASH_SOURCE vazio)
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]:-}" == "bash" ]]; then
  # Rodando via curl | bash — baixar e executar deployer/install.sh direto
  DEPLOYER_URL="https://raw.githubusercontent.com/tallessouza/legendsclaw-deployer/main/deployer/install.sh"
  exec bash <(curl -sSL "$DEPLOYER_URL") "$@"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec bash "${SCRIPT_DIR}/deployer/install.sh" "$@"
fi
