# Stack de Observabilidade e Resiliencia

**Status atual em 22/04/2026**: stack sobe com `docker compose up -d --build`, os 6 servicos ficam saudaveis e o fluxo de alerta local esta operacional.

## Visao geral

Esta stack usa:

- `prometheus`: coleta de metricas e avaliacao das regras
- `grafana`: dashboards provisionados
- `node_exporter`: metricas do host
- `app`: aplicacao Flask instrumentada com `/health`, `/metrics`, `/status/<code>` e `/delay/<seconds>`
- `alertmanager`: agrupamento, roteamento e inibicao de alertas
- `notifier`: relay HTTP que recebe payloads do Alertmanager e publica em Slack e/ou Discord via webhook

Fluxo de notificacao:

```text
Prometheus -> Alertmanager -> notifier -> Slack / Discord
```

## Quick start

### 1. Configurar ambiente

```bash
cd /Users/mateustibaes/Desktop/Observabilidade
cp .env.example .env
```

Preencha no `.env`:

- `SLACK_WEBHOOK_URL` com o webhook real do Slack, se quiser enviar para Slack
- `DISCORD_WEBHOOK_URL` com o webhook real do Discord, se quiser enviar para Discord

Se os campos ficarem vazios, a stack continua funcionando e o `notifier` responde com `slack_skipped` e `discord_skipped`.

### 2. Subir a stack

```bash
docker compose up -d --build
docker compose ps
```

Esperado: `prometheus`, `grafana`, `node_exporter`, `app`, `alertmanager` e `notifier` em estado `Up`.

### 3. Acessar interfaces

| Servico | URL | Credenciais |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | `admin` / `admin` |
| Prometheus | http://localhost:9090 | sem auth |
| Alertmanager | http://localhost:9093 | sem auth |
| App | http://localhost:8080 | sem auth |

## Estado real validado

Validacoes feitas nesta maquina em `22/04/2026`:

- `docker compose up -d --build` executado com sucesso
- `docker compose ps` mostrando 6 servicos saudaveis
- `http://localhost:8080/health` retornando `{"status":"healthy"}`
- `http://localhost:8080/metrics` expondo metricas Prometheus
- `http://localhost:9090/api/v1/targets` com `application`, `node_exporter` e `prometheus` em `up`
- teste local no `notifier` retornando `{"errors":[],"results":["slack_skipped","discord_skipped"]}` sem webhooks configurados

## Alertas configurados

### Infraestrutura

| Alerta | Condicao | Severidade |
|--------|----------|------------|
| `HighCpuWarning` | CPU > 80% por 2 min | warning |
| `HighCpuCritical` | CPU > 95% por 1 min | critical |
| `LowMemoryAvailable` | uso de memoria > 90% por 2 min | critical |

### Aplicacao

| Alerta | Condicao | Severidade |
|--------|----------|------------|
| `ServiceDown` | `up{job="application"} == 0` por 30 s | critical |
| `HighErrorRate` | erros 5xx > 5% por 5 min | warning |
| `HighLatencyP99` | P99 > 1s por 5 min | warning |

### Monitoramento

| Alerta | Condicao | Severidade |
|--------|----------|------------|
| `PrometheusDown` | `up{job="prometheus"} == 0` por 1 min | critical |

## Testes uteis

### Ver targets

```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

### Verificar relay de notificacao

```bash
docker compose exec -T notifier python - <<'PY'
import json, urllib.request
payload = {
    "status": "firing",
    "alerts": [{
        "status": "firing",
        "labels": {"alertname": "TestNotification", "severity": "warning", "instance": "manual-test"},
        "annotations": {"summary": "Teste manual do relay"}
    }]
}
req = urllib.request.Request(
    "http://localhost:5001/alert",
    data=json.dumps(payload).encode(),
    headers={"Content-Type": "application/json"},
)
with urllib.request.urlopen(req) as response:
    print(response.read().decode())
PY
```

### Simular falhas

```bash
./scripts/simulate_failure.sh list
./scripts/simulate_failure.sh crash
./scripts/simulate_failure.sh cpu
./scripts/simulate_failure.sh memory
./scripts/simulate_failure.sh combined
```

## Estrutura principal

```text
observabilidade/
├── docker-compose.yml
├── .env.example
├── alertmanager.yml
├── prometheus/
│   ├── prometheus.yml
│   └── alerts.rules.yml
├── grafana/provisioning/
├── app/
├── notifier/
├── scripts/
├── RUNBOOK.md
├── GUIA_INICIO.md
├── STACK_OPERATIONAL.md
└── FASE2_SLACK.md
```

## Observacoes

- A integracao nao e mais "Slack direto no Alertmanager". Hoje o envio externo acontece exclusivamente via `notifier`.
- O `templates/slack.tmpl` ainda existe no repositorio, mas nao participa do fluxo atual.
- Sem webhooks reais, a validacao termina no relay local; com webhooks reais, as mensagens seguem para Slack e Discord sem alterar o `alertmanager.yml`.
