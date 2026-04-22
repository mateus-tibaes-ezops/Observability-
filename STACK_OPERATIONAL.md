# Stack Operacional

**Data da verificacao**: 22/04/2026  
**Estado**: stack local operacional para testes

## Resumo executivo

Estado confirmado nesta maquina:

- `docker compose up -d --build` executado com sucesso
- 6 containers em `Up` e com `healthcheck` verde
- aplicacao expondo `/health` e `/metrics`
- Prometheus enxergando `application`, `node_exporter` e `prometheus`
- Alertmanager carregando `alertmanager.yml` sem erro
- relay `notifier` aceitando payloads e pronto para enviar a Slack e Discord

## Containers

Saida observada em `docker compose ps`:

```text
alertmanager    Up (healthy)
app             Up (healthy)
grafana         Up (healthy)
node_exporter   Up (healthy)
notifier        Up (healthy)
prometheus      Up (healthy)
```

## Fluxo de alerta vigente

```text
Prometheus -> Alertmanager -> notifier -> Slack / Discord
```

Receivers atuais:

- `alertmanager.yml`: receiver padrao `notifications-relay`
- `webhook_configs.url`: `http://notifier:5001/alert`

Nao existe envio direto do Alertmanager para Slack.

## Checks feitos

### App

```bash
curl -s http://localhost:8080/health
curl -s http://localhost:8080/metrics
```

Resultado:

- `/health` respondeu `{"status":"healthy"}`
- `/metrics` expôs metricas `http_requests_total`, `http_request_duration_seconds` e gauges/process metrics

### Prometheus

```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, url: .scrapeUrl}'
```

Resultado:

- `application` -> `up`
- `node_exporter` -> `up`
- `prometheus` -> `up`

### Notifier

Teste interno executado no proprio container:

```json
{"errors":[],"results":["slack_skipped","discord_skipped"]}
```

Interpretacao:

- o fluxo interno funciona
- falta apenas configurar webhooks reais para a confirmacao externa

## Divergencias removidas da documentacao

Os seguintes pontos estavam incorretos em documentos antigos e nao devem mais ser considerados verdadeiros:

- app baseada em `httpbin` sem `/metrics`
- stack com apenas 5 containers
- receiver `null` ou integracao "Slack direto no Alertmanager"
- claims de "pronto para producao"
- instrucao para alterar `alertmanager.yml` ao ativar Slack

## Proximo passo para validacao completa

Para confirmar entrega no Slack e/ou Discord, basta preencher `.env` com webhooks validos e reenviar um payload de teste. Nenhuma mudanca adicional de topologia e necessaria.
