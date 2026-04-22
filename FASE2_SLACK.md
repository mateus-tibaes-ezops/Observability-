# Fase 2 - Notificacoes Slack e Discord

**Atualizado em 22/04/2026** para o fluxo real da stack.

## Topologia atual

O nome historico deste documento fala em "Slack", mas a implementacao atual centraliza notificacoes em um relay proprio:

```text
Prometheus -> Alertmanager -> notifier -> Slack / Discord
```

Componentes envolvidos:

- `alertmanager.yml`: roteia todos os alertas para `http://notifier:5001/alert`
- `notifier/notifier.py`: formata o payload e publica em Slack e Discord
- `.env`: injeta `SLACK_WEBHOOK_URL` e `DISCORD_WEBHOOK_URL` no container `notifier`

## O que o notifier envia

Formato atual da mensagem:

```text
[FIRING] 1 alerta(s)

WARNING TestNotification
Instancia: manual-test
Resumo: Teste manual do relay
Descricao: Validacao do conteudo encaminhado pelo notifier
Inicio: 2026-04-22T14:50:00Z
Dashboard: http://localhost:3000/d/observabilidade-main
Runbook: http://localhost:9090/rules

Emitido em: <timestamp UTC>
```

Observacoes:

- Slack recebe `{"text": ...}`
- Discord recebe `{"content": ...}` truncado para 1900 caracteres
- placeholders como `YOUR/WEBHOOK/URL` e `PLACEHOLDER` sao ignorados

## Configuracao

### 1. Criar `.env`

```bash
cp .env.example .env
```

### 2. Preencher webhooks reais

```dotenv
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

### 3. Aplicar no relay

```bash
docker compose up -d notifier
```

## Verificacoes uteis

### Confirmar health do relay

```bash
docker compose exec -T notifier python - <<'PY'
import urllib.request
print(urllib.request.urlopen("http://localhost:5001/health").read().decode())
PY
```

### Confirmar formato gerado

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
            "description": "Validacao do conteudo encaminhado pelo notifier",
            "dashboard_url": "http://localhost:3000/d/observabilidade-main",
            "runbook_url": "http://localhost:9090/rules"
        },
        "startsAt": "2026-04-22T14:50:00Z"
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

Com webhooks ausentes, o retorno esperado e:

```json
{"errors":[],"results":["slack_skipped","discord_skipped"]}
```

Com webhooks validos, o esperado e:

```json
{"errors":[],"results":["slack_sent","discord_sent"]}
```

## Troubleshooting

### `slack_skipped` ou `discord_skipped`

O webhook correspondente esta vazio ou ainda contem placeholder.

### Erro HTTP ao enviar

Verifique:

- URL do webhook
- se o webhook ainda esta ativo no workspace/canal
- se o container `notifier` foi recriado apos editar `.env`

### Preciso mudar `alertmanager.yml`?

Nao. Enquanto o endpoint `http://notifier:5001/alert` continuar sendo o receiver, a integracao externa fica toda concentrada no `notifier`.
