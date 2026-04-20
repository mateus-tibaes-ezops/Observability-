# VERIFICAÇÃO DA INSTALAÇÃO - FASE 1

## ✅ Checklist de Verificação

### 1. Verificar se containers estão rodando
```bash
docker compose ps

# Esperado: 4 containers em status "Up"
# - prometheus
# - grafana
# - node_exporter
# - app
```

### 2. Verificar conectividade Prometheus → Targets
```bash
# Acessar: http://localhost:9090/targets
# Esperado: 3 jobs em status "UP"
#  - prometheus (job_prometheus)
#  - node_exporter (job_node_exporter)
#  - application (job_application)
```

### 3. Testar métricas no Prometheus
```bash
# Prometheus UI: http://localhost:9090

# Executar query:
up

# Esperado: 3 linhas, todas com valor 1
# up{job="application"} 1
# up{job="node_exporter"} 1
# up{job="prometheus"} 1
```

### 4. Verificar Grafana
```bash
# Acessar: http://localhost:3000
# Login: admin / admin
# Esperado:
#  - Datasource "Prometheus" disponível
#  - Dashboard "Observabilidade - Dashboard Principal (FASE 1)" carregado
```

### 5. Testar Alertas
```bash
# Prometheus UI: http://localhost:9090/alerts
# Esperado: Lista de regras de alerta (status verde = OK)
```

### 6. Verificar Logs
```bash
# Geral
docker compose logs --tail=50

# Específico
docker compose logs prometheus
docker compose logs grafana
docker compose logs node_exporter
```

---

## 🐛 Problemas Comuns

### Erro: "connection refused" no Prometheus
**Solução:**
```bash
# Aguarde 30s para containers iniciarem
sleep 30
docker compose ps

# Se ainda não conectar, verificar rede
docker network ls | grep observabilidade
```

### Grafana não encontra Prometheus
**Solução:**
```bash
# Verificar se datasource foi criado
docker compose exec grafana curl -s http://prometheus:9090 | head

# Se erro, reiniciar
docker compose restart grafana
```

### Métricas vazias após 1 minuto
**Solução:**
```bash
# Node Exporter pode levar 2min para expor primeira métrica
sleep 120

# Verificar endpoint
docker compose exec node_exporter wget -O- http://localhost:9100/metrics | head
```

---

## 🔧 Comandos Úteis

### Recarregar configs Prometheus (hot-reload)
```bash
docker compose exec prometheus curl -X POST http://localhost:9090/-/reload
```

### Limpar volumes e recomeçar
```bash
docker compose down -v
docker compose up -d
```

### Ver espaço usado por métricas
```bash
docker exec prometheus du -sh /prometheus
```

### Exportar métricas para arquivo
```bash
docker compose exec prometheus curl -s 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=up' > metrics.json
```

---

## 📊 Queries Prontas para Teste

No Prometheus (http://localhost:9090), copie e cole:

```promql
# 1. Verificar quais containers estão up
up

# 2. CPU usage (%)
(100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))

# 3. Memória disponível (%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# 4. Número de targets monitorados
count(up)

# 5. Uptime do Prometheus (em horas)
(time() - process_start_time_seconds{job="prometheus"}) / 3600
```

---

## 📈 Próximas Verificações (FASE 2)

Quando avançar para Alertmanager + Slack:

- [ ] Alertmanager rodando e conectado a Prometheus
- [ ] Webhook Slack configurado
- [ ] Teste de alerta manual enviando para Slack
- [ ] Template Slack renderizando corretamente

---

**Status**: ✅ FASE 1 Completa e Funcional
