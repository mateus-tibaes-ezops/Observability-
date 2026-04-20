# ROADMAP - Fases 2 e 3

## 📋 Status Atual
- ✅ **FASE 1**: Prometheus + Grafana + Dashboards
  - [x] docker-compose.yml
  - [x] prometheus.yml com jobs
  - [x] alerts.rules.yml com 6 regras
  - [x] Dashboards Grafana (8 painéis)
  - [x] SLOs/SLIs documentados
  - [x] README completo

---

## 📅 FASE 2 — Alertas via Slack + Alertmanager

### Arquivos a Criar

- `alertmanager.yml` - Configuração de alerting
- `alertmanager/` - Diretório para dados persistentes
- `templates/slack.tmpl` - Template de mensagens Slack
- `docker-compose.yml` - Adicionar Alertmanager service

### Implementação

#### 1. Alertmanager

```dockerfile
# Adicionar ao docker-compose.yml

  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - ./templates/slack.tmpl:/etc/alertmanager/slack.tmpl:ro
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    environment:
      - SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL}
    networks:
      - observability
```

#### 2. alertmanager.yml

- Receiver `slack-notifications`
- Webhook URL via env var
- Agrupamento: `alertname` + `job`
- group_wait: 30s
- group_interval: 5m
- repeat_interval: 4h

#### 3. templates/slack.tmpl

```
{{ define "slack.default" }}
🔴 {{ .GroupLabels.severity | upper }}
Alerta: {{ .GroupLabels.alertname }}
Serviço: {{ .GroupLabels.job }}

{{ range .Alerts.Firing }}
  • {{ .Annotations.description }}
  Valor: {{ .Annotations.summary }}
{{ end }}

[Ver Dashboard](http://grafana:3000)
[Runbook]({{ (index .Alerts 0).Annotations.runbook_url }})
{{ end }}
```

#### 4. Atualizar prometheus.yml

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'alertmanager:9093'
```

### Testes

```bash
# 1. Iniciar stack com Alertmanager
docker compose up -d

# 2. Verificar se conectou
docker compose logs alertmanager | grep "listening"

# 3. Disparo manual de alerta (curl fake alert)
# Ou simular alta CPU com stress-ng

# 4. Verificar no Slack se mensagem chegou
```

---

## 🔥 FASE 3 — Simulação de Falha e Runbooks

### Arquivos a Criar

- `scripts/simulate_failure.sh` - Script de simulação
- `RUNBOOK.md` - Procedimentos de resposta
- `POST_MORTEM_TEMPLATE.md` - Template de análise pós-incidente

### simulate_failure.sh

```bash
#!/bin/bash

case "$1" in
  cpu)
    # Simular alta CPU por 3 min
    docker run --rm -d alpine stress-ng --cpu 4 --timeout 3m
    echo "🔥 CPU stress ativado por 3 minutos"
    ;;
  
  crash)
    # Matar app
    docker compose kill app
    echo "💀 App crashed"
    # Recuperação automática
    sleep 5 && docker compose up -d app
    ;;
  
  error)
    # Injetar 500 via env
    docker compose exec app env INJECT_ERRORS=true bash
    ;;
esac
```

### RUNBOOK.md

#### Runbook — Service Down

```
🔴 ALERTA: ServiceDown

DETECÇÃO:
- Slack notifica que up{job="application"} == 0
- Grafana Dashboard → Service Health mostra vermelho

DIAGNÓSTICO:
1. Verificar status do container
   docker compose ps app

2. Verificar logs
   docker compose logs app | tail -50

3. Verificar conectividade
   docker compose exec app ping -c 1 prometheus

REMEDIAÇÃO (em ordem):
1. Restart suave
   docker compose restart app
   (aguardar 30s para verificar se up==1)

2. Verificar recursos
   docker stats
   (se CPU/MEM alta, fazer scale)

3. Rollback
   git log --oneline | head -3
   docker compose up -d (com versão anterior)

4. Escalonamento
   docker compose up --scale app=3 -d

PÓS-INCIDENTE:
- Ticket: ops/incident-YYYYMMDD-HHMM
- Template: POST_MORTEM_TEMPLATE.md
```

#### Runbook — High CPU

```
🟡 ALERTA: HighCpuWarning / HighCpuCritical

DIAGNÓSTICO:
1. Ver processos
   docker exec node_exporter top -b -n 1

2. Histórico gráfico
   Grafana → CPU Usage Over Time

3. Queries Prometheus
   - top_cpu_processes
   - container_cpu_usage

REMEDIAÇÃO:
- Se processo runaway:
  kill PID

- Se carga normal:
  Scale horizontal (add replicas)

- Se memory leak:
  Restart container
```

---

## 📊 Timeline Estimada

| Fase | Componentes | Tempo Est. | Status |
|------|-------------|----------|--------|
| 1 | Prometheus + Grafana | ✅ Pronto | Completo |
| 2 | Alertmanager + Slack | 30 min | Próxima |
| 3 | Runbooks + Simulação | 45 min | Depois |

---

## 🎯 Sucesso = Confirmação

**FASE 2 confirmada quando:**
- [ ] Alertmanager roda sem erros
- [ ] Slack recebe primeira mensagem de alerta
- [ ] Template Slack renderiza com dados corretos
- [ ] Alertas agrupados conforme config (group_wait: 30s)

**FASE 3 confirmada quando:**
- [ ] Script simula falha com sucesso
- [ ] Runbook executado resolveu problema em <5 min
- [ ] Template post-mortem preenchido

---

**Próximo passo**: Confirmar FASE 1 → Prosseguir com FASE 2
