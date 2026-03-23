#!/bin/bash
# Local: /opt/ptin/automation/ops/sigo-automation/deploy.sh

REPO_DIR="/opt/ptin/automation/ops/sigo-automation"

cd $REPO_DIR || exit

# 1. Atualiza o código vindo do GitHub (HTTPS via Proxy)
git pull origin main

# 2. Executa o Playbook usando o inventário que acabaste de me mostrar
ansible-playbook -i inventory/hosts playbooks/config_luncher.yml/