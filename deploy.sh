#!/bin/bash
cd /opt/ptin/automation/ops/sigo-automation
git pull origin master

# Executar o playbook principal do Ansible para configurar o ambiente
ansible-playbook -i inventory/hosts playbooks/config_luncher.yml 
