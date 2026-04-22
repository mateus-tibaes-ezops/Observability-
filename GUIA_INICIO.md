# Guia de Inicio Rapido

**Atualizado em 22/04/2026** para refletir a stack real do repositorio.

## O que existe hoje

- 6 containers: `prometheus`, `grafana`, `node_exporter`, `app`, `alertmanager`, `notifier`
- aplicacao Flask instrumentada com metricas Prometheus
- Alertmanager roteando para `notifier`
- `notifier` preparado para publicar em Slack e Discord via webhook
- dashboards e datasources do Grafana provisionados
- script `scripts/simulate_failure.sh` para exercitar cenarios de falha

## Subir em poucos minutos

### 1. Preparar `.env`

```bash
cd /Users/mateustibaes/Desktop/Observabilidade
cp .env.example .env
```

Preencha os webhooks que quiser ativar:

```dotenv
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

Se algum webhook ficar vazio, o `notifier` apenas ignora aquele destino.

### 2. Subir a stack

```bash
docker compose up -d --build
docker compose ps
```

Esperado:

- `prometheus` healthy
- `grafana` healthy
- `node_exporter` healthy
- `app` healthy
- `alertmanager` healthy
- `notifier` healthy

### 3. Validar rapidamente

```bash
curl -s http://localhost:8080/health
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

Interfaces:

| Servico | URL |
|---------|-----|
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| Alertmanager | http://localhost:9093 |
| App | http://localhost:8080 |

## Como as notificacoes funcionam

Fluxo real:

```text
Prometheus -> Alertmanager -> notifier -> Slack / Discord
```

Implicacoes praticas:

- o `alertmanager.yml` nao aponta para webhook do Slack
- nao existem mais receivers `slack-notifications` ou `slack-critical`
- a configuracao externa mora no `.env`, consumida pelo container `notifier`

## Testes recomendados

### Teste local do relay

```bash
docker compose exec -T notifier python - <<'PY'
import json, urllib.request
payload = {
    "status": "firing",
    "alerts": [{
        "status": "firing",
        "labels": {"alertname": "TestNotification", "severity": "warning", "instance": "manual-test"},
        "annotations": {
            "summary": "Teste manual do relay",
            "description": "Validacao do conteudo encaminhado pelo notifier"
        }
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

Sem webhooks reais, o retorno esperado e:

```json
{"errors":[],"results":["slack_skipped","discord_skipped"]}
```

### Simular alertas

```bash
./scripts/simulate_failure.sh crash
./scripts/simulate_failure.sh cpu
./scripts/simulate_failure.sh combined
```

## FAQ curta

### Como trocar o webhook?

Edite `.env` e reinicie apenas o relay:

```bash
docker compose up -d notifier
```

### Preciso mexer no `alertmanager.yml` para Slack ou Discord?

Nao. O `alertmanager.yml` continua apontando para `http://notifier:5001/alert`.

### A stack esta pronta para producao?

Nao como esta. Ela esta pronta para desenvolvimento, demonstracao e testes locais. Ainda faltam itens como auth forte, secrets management, backup e hardening dos servicos Flask.
