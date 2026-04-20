#!/bin/sh
# ============================================================
# Entrypoint para Alertmanager
# Substitui variáveis de ambiente no alertmanager.yml
# ============================================================

set -e

# Se a variável não está setada, usa o padrão
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-https://hooks.slack.com/services/PLACEHOLDER}"
SLACK_CHANNEL="${SLACK_CHANNEL:-#alerts-infra}"

# Criar arquivo de configuração com as variáveis substituídas
sed \
  -e "s|ALERTMANAGER_SLACK_WEBHOOK|$SLACK_WEBHOOK_URL|g" \
  -e "s|ALERTMANAGER_SLACK_CHANNEL|$SLACK_CHANNEL|g" \
  /etc/alertmanager/alertmanager.yml > /tmp/alertmanager.yml

# Executa o alertmanager com a configuração processada
exec /bin/alertmanager \
  --config.file=/tmp/alertmanager.yml \
  --storage.path=/alertmanager \
  "$@"
