# FASE 2 — Alertmanager + Slack

**Status**: ✅ Alertmanager + Template Slack Implementados

## 🎯 O Que foi Criado

### 1. Alertmanager Service
**Arquivo**: `docker-compose.yml` (novo serviço)

- Porta: 9093
- Volume persistente: `alertmanager_data`
- Configuração: `alertmanager.yml`
- Templates: `templates/slack.tmpl`
- Healthcheck: ativo

### 2. Configuração do Alertmanager
**Arquivo**: `alertmanager.yml`

**Características:**
- ✅ Receiver: `slack-notifications`
- ✅ Webhook Slack via env var `SLACK_WEBHOOK_URL`
- ✅ Agrupamento: `alertname` + `job` + `severity`
- ✅ group_wait: 30s (críticos: 10s)
- ✅ repeat_interval: 4h (críticos: 30m)
- ✅ Rotas específicas: critical vs warning
- ✅ Inhibit rules: suprimir alertas redundantes
- ✅ Actions: buttons para Silenciar, Prometheus, Grafana

### 3. Template Slack
**Arquivo**: `templates/slack.tmpl`

**Formato:**
```
🔴 CRITICAL • HighCpuCritical

📝 [Descrição do alerta]
💾 Status: [valor atual vs threshold]
🖥️ Instância: app:8080
🎯 Serviço: application
📚 Runbook
📊 Dashboard

Tempo: 14:30:25 UTC
```

### 4. Integração Prometheus ↔ Alertmanager
**Arquivo**: `prometheus/prometheus.yml` (atualizado)

- Configurado endpoint do Alertmanager: `alertmanager:9093`
- Relabel configs: adiciona label `alertmanager`

---

## 🚀 Configuração Slack (Pré-requisito)

### Passo 1: Criar Webhook Slack

1. Acesse: https://api.slack.com/apps/
2. Clique **Create New App** → **From scratch**
3. Nome: `Observabilidade Alerts`
4. Workspace: Selecione seu workspace
5. Menu esquerdo → **Incoming Webhooks** → **On**
6. **Add New Webhook to Workspace**
7. Escolha um canal (ex: `#alerts-infra`)
8. Copie a URL gerada (exemplo):
   ```
   https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXX
   ```

### Passo 2: Configurar .env

```bash
# Copie .env.example para .env
cp .env.example .env

# Edite .env e adicione:
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXX
SLACK_CHANNEL=#alerts-infra
```

### Passo 3: Validar

```bash
# Testar se webhook funciona
curl -X POST $SLACK_WEBHOOK_URL \
  -H 'Content-Type: application/json' \
  -d '{"text": "✅ Webhook funcionando!"}'

# Deve aparecer mensagem no Slack
```

---

## ▶️ Iniciar Stack com Alertmanager

```bash
# Certifique-se de estar no diretório
cd /Users/mateustibaes/Desktop/Observabilidade

# Criar .env com webhook Slack
cp .env.example .env
# Edite .env com SLACK_WEBHOOK_URL real

# Inicie stack (5 serviços agora)
docker compose up -d

# Verifique os 5 containers
docker compose ps

# Esperado: prometheus, grafana, node_exporter, app, alertmanager (todos Up)
```

---

## 🔍 Verificações

### 1. Alertmanager Rodando

```bash
# Check status
docker compose ps alertmanager

# Logs
docker compose logs -f alertmanager

# Interface web
# Acesse: http://localhost:9093
# Esperado: UI do Alertmanager funcionando
```

### 2. Prometheus Conectado ao Alertmanager

```bash
# Acessar: http://localhost:9090/config
# Procurar por: "alerting_config"
# Esperado:
#   alertmanagers:
#     - targets:
#         - alertmanager:9093

# Ou via curl:
docker compose exec prometheus wget -O- http://alertmanager:9093/-/healthy
```

### 3. Regras de Alerta no Prometheus

```bash
# Acesse: http://localhost:9090/alerts
# Esperado:
#   - 6 regras listadas
#   - Status: green (OK) ou firing (alerta ativo)
```

---

## 🧪 Teste de Alerta End-to-End

### Opção A: Disparar Manualmente (Test Webhook)

```bash
# Enviar payload de teste para Alertmanager
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "job": "test"
    },
    "annotations": {
      "summary": "Teste de alerta",
      "description": "Este é um alerta de teste para validar Slack"
    }
  }]'

# Esperado: Mensagem aparece no Slack após ~30s (group_wait)
```

### Opção B: Causar Alta CPU (Realista)

```bash
# Instalar stress-ng se necessário
brew install stress-ng

# OU via Docker:
docker run --rm -d --cpus=2 progrium/stress --cpu 4

# Monitorar em Prometheus:
# http://localhost:9090/graph
# Query: (100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))

# Quando CPU > 80% por 2min → HighCpuWarning no Slack ⚠️
# Quando CPU > 95% por 1min → HighCpuCritical no Slack 🔴

# Parar stress:
docker kill $(docker ps | grep progrium | awk '{print $1}')
```

### Opção C: Simular Service Down

```bash
# Parar o container app
docker compose stop app

# Prometheus detectará: up{job="application"} == 0
# Após 30s → Alerta ServiceDown no Slack 🔴

# Recuperar:
docker compose start app
```

---

## 📝 Observar Comportamento no Slack

### Primeira Notificação (group_wait: 30s)
```
🟡 WARNING • HighCpuWarning

📝 CPU está acima de 80% por mais de 2 minutos.
💾 Status: Valor atual: 85%
🖥️ Instância: node-exporter
🎯 Serviço: node_exporter
📚 Runbook: https://wiki.company.com/runbooks/high-cpu
📊 Dashboard: http://grafana:3000/d/node-exporter
```

### Agrupamento
- Múltiplos alertas do mesmo job aparecem em **1 mensagem** (30s batch)
- Não spam: 1 mensagem a cada 5m (group_interval)

### Resolução
```
✅ RESOLVIDO: HighCpuWarning

  • node-exporter: 14:35:22
```

---

## ⚙️ Customizações Úteis

### Alterar Timing de Agrupamento

Edite `alertmanager.yml`:

```yaml
route:
  group_wait: 10s      # Mais rápido (padrão: 30s)
  group_interval: 2m   # Mais frequente (padrão: 5m)
```

Depois: `docker compose up -d alertmanager`

### Alterar Canal Slack

```bash
# Em .env
SLACK_CHANNEL=#ops-critical

# Restart
docker compose restart alertmanager
```

### Adicionar Novo Receiver (ex: Email)

No `alertmanager.yml`:

```yaml
receivers:
  - name: 'email'
    email_configs:
      - to: 'ops@company.com'
        from: 'alertas@company.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'seu-email@gmail.com'
        auth_password: '${EMAIL_PASSWORD}'
```

---

## 🐛 Troubleshooting

### Alertmanager não conecta ao Slack

```bash
# Verificar webhook URL
docker compose logs alertmanager | grep -i webhook

# Validar URL manualmente
curl -X POST $SLACK_WEBHOOK_URL \
  -H 'Content-Type: application/json' \
  -d '{"text": "Test"}'

# Se erro 404/403: webhook expirou ou incorreto
# Gerar novo em https://api.slack.com/apps/
```

### Prometheus não envia alertas

```bash
# Verificar conectividade
docker compose exec prometheus curl http://alertmanager:9093/-/healthy

# Checar configuração Prometheus
docker compose logs prometheus | grep alerting

# Forçar reload:
docker compose exec prometheus curl -X POST http://localhost:9090/-/reload
```

### Alertas não agrupam

```bash
# Validar grupo_by em alertmanager.yml
# Deve estar: group_by: [alertname, job, severity]

# Ver grupos ativos:
# http://localhost:9093/#/alerts
```

### Template Slack não renderiza

```bash
# Verificar template
docker compose exec alertmanager cat /etc/alertmanager/slack.tmpl

# Validar YAML
docker run -it --rm -v $(pwd):/work sdesbure/yamllint alertmanager.yml

# Check logs
docker compose logs alertmanager | grep -i template
```

---

## 📊 Monitoramento do Alertmanager

### Métricas Expostas

```
http://localhost:9093/metrics

# Principais:
alertmanager_alerts                    # Total de alertas
alertmanager_alerts_received           # Alertas recebidos
alertmanager_alerts_invalid            # Alertas inválidos
alertmanager_notification_requests     # Notificações enviadas
alertmanager_notification_latency_seconds  # Latência Slack
```

---

## 🎯 Próximo Passo: FASE 3

Quando FASE 2 estiver validada:

### Criar `scripts/simulate_failure.sh`
- Opção A: Crash da app (kill container)
- Opção B: Alta CPU (stress-ng)
- Opção C: Injetar HTTP 500

### Criar `RUNBOOK.md`
- Procedimentos para cada alerta
- Diagnóstico com comandos
- Remediação step-by-step

### Criar `POST_MORTEM_TEMPLATE.md`
- Template de análise pós-incidente

---

## 📚 Referências

- [Alertmanager Docs](https://prometheus.io/docs/alerting/latest/overview/)
- [Slack Integration](https://prometheus.io/docs/alerting/latest/configuration/#slack_config)
- [Template Language](https://prometheus.io/docs/alerting/latest/notification_template_reference/)
- [Slack API Apps](https://api.slack.com/apps/)

---

**Status**: ✅ FASE 2 Implementada e Pronta para Teste
**Próximo**: Confirmar funcionamento → FASE 3
