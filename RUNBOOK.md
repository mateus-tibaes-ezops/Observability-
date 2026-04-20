# RUNBOOK - Procedimentos de Resposta a Incidentes

**Versão**: 1.0  
**Data**: 20 de abril de 2026  
**Atualização**: [Sempre que adicionar novo alerta]

---

## 📋 Índice

1. [ServiceDown](#runbook—service-down) - Serviço offline
2. [HighCpuWarning](#runbook—high-cpu-warning) - CPU elevada
3. [HighCpuCritical](#runbook—high-cpu-critical) - CPU crítica
4. [LowMemoryAvailable](#runbook—low-memory-available) - Memória crítica
5. [HighErrorRate](#runbook—high-error-rate) - Taxa de erros elevada
6. [HighLatencyP99](#runbook—high-latencyp99) - Latência elevada
7. [PrometheusDown](#runbook—prometheus-down) - Monitoramento offline

---

## RUNBOOK — Service Down

### 🔴 Alerta
```
Alertname:  ServiceDown
Severity:   CRITICAL 🔴
Condição:   up{job="application"} == 0 por mais de 30 segundos
SLA Impact: Availability SLO violado (99.5% target)
```

### 🔍 DETECÇÃO

**Origem do Alerta:**
- Slack: mensagem com 🔴 ServiceDown + instância + job
- Prometheus: http://localhost:9090/alerts → estado "firing"
- Grafana: painel "Service Health Status" → vermelho

**Timeline:**
```
T+0s:   Serviço para de responder
T+30s:  Primeiro alerta dispara
T+30-60s: Notificação Slack recebida
```

### 📊 DIAGNÓSTICO (2-3 min)

#### Passo 1: Verificar Status do Container

```bash
# Listar containers
docker compose ps

# Esperado: status "Up" para o container app
# Se "Exited": serviço crashou

# Ver logs recentes
docker compose logs --tail=100 app

# Procurar por:
# - Stack traces de erro
# - OutOfMemory (OOM)
# - Segmentation fault
# - Port binding error (já em uso)
```

#### Passo 2: Testar Conectividade

```bash
# Ping simples
curl -v http://localhost:8080/health

# Esperado: HTTP 200 ou 503 (importante: resposta)
# Se erro "Connection refused": porta não listening

# Dentro do container
docker compose exec app bash
  netstat -tulpn | grep LISTEN
  ps aux | grep app
  exit
```

#### Passo 3: Verificar Recursos

```bash
# Ver uso de recursos
docker stats --no-stream app

# Verificar:
# - CPU: se > 100%, possível CPU throttling
# - MEM: se > limite, OOM Kill provável
# - NET: se alto, possível DDoS ou leak

# Limites definidos?
docker inspect app | grep -A 5 "HostConfig"
```

#### Passo 4: Verificar Dependências

```bash
# Se app depende de outros serviços:
docker compose logs prometheus
docker compose logs grafana

# Testar conectividade entre containers
docker compose exec app ping prometheus
docker compose exec app curl http://prometheus:9090/-/healthy
```

#### Passo 5: Verificar Porta em Uso

```bash
# Ver o que está usando a porta 8080
lsof -i :8080

# Se outro processo: kill $(lsof -t -i :8080)
```

### ✅ REMEDIAÇÃO (5-10 min, em ordem)

#### Nível 1: Restart Simples (80% resolve)

```bash
# Restart container
docker compose restart app

# Aguardar 10s para inicializar
sleep 10

# Verificar se voltou
curl http://localhost:8080/health

# Verificar em Prometheus
# http://localhost:9090/targets → Application status
```

**Esperado**: 
- ✅ Container em "Up"
- ✅ HTTP 200 em /health
- ✅ Prometheus mostra up == 1
- ✅ Slack recebe "RESOLVIDO"

---

#### Nível 2: Se Restart não Funciona

```bash
# 2a. Forçar parada e remover
docker compose kill app
docker compose rm -f app

# Esperar alguns segundos
sleep 5

# Recriar com docker compose
docker compose up -d app

# 2b. Se falhar, verificar logs de erro
docker compose logs --tail=50 app
```

---

#### Nível 3: Rollback para Versão Anterior

```bash
# Ver histórico de imagens
docker image ls | grep app

# Se usar tag de versão, voltar para anterior
docker compose down app

# Editar docker-compose.yml: image tag
# De: app:latest → app:v1.2.3

docker compose up -d app
```

---

#### Nível 4: Escalonamento Horizontal

```bash
# Se restart não funciona, pode ser problema de recursos
# Adicionar mais instâncias

# Editar docker-compose.yml
# Se usar swarm/k8s:
docker compose up --scale app=3 -d

# Redirecionar tráfego entre instâncias
# (requer load balancer, ex: nginx)
```

---

#### Nível 5: Escalação Humana 🚨

```bash
# Se todas opções falharem:

1. Criar ticket: ops/incident-YYYYMMDD-HHmm
2. Notificar Team Lead via Slack
3. Ativar Incident Commander
4. Preparar status page para clientes
5. Investigação pós-incidente (POST_MORTEM_TEMPLATE.md)
```

### 📈 MONITORAMENTO Durante Remediação

```bash
# Terminal 1: Watch logs
docker compose logs -f app

# Terminal 2: Watch status
while true; do
  curl -s http://localhost:8080/health && echo " ✓" || echo " ✗"
  sleep 2
done

# Terminal 3: Prometheus
# Abrir: http://localhost:9090/graph
# Query: up{job="application"}
```

### ✨ VALIDAÇÃO - Antes de Declarar Resolvido

- [ ] `docker compose ps app` mostra "Up"
- [ ] `curl http://localhost:8080/health` retorna 200
- [ ] Prometheus: `up{job="application"}` == 1
- [ ] Grafana: Service Health Status = verde
- [ ] Slack: mensagem "✅ RESOLVIDO"
- [ ] Não há erros nos logs recentes

### 📝 Documentação Pós-Incidente

Ver: [POST_MORTEM_TEMPLATE.md](POST_MORTEM_TEMPLATE.md)

---

## RUNBOOK — High CPU Warning

### 🟡 Alerta
```
Alertname:  HighCpuWarning
Severity:   WARNING 🟡
Condição:   CPU > 80% por mais de 2 minutos
SLA Impact: Pode levar a latência elevada
```

### 🔍 DIAGNÓSTICO (2-3 min)

```bash
# 1. Verificar CPU em tempo real
top -b -n 1 | head -20

# Procurar processos com alto %CPU

# 2. Via Docker
docker stats --no-stream | grep -E "app|prometheus|grafana"

# 3. Prometheus
# Query: (100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))

# 4. Grafana
# Dashboard: "CPU Usage Over Time" últimas 5min
```

### ✅ REMEDIAÇÃO (Nível 1: Investigar)

```bash
# 1a. Processos top consumers
ps aux --sort=-%cpu | head -10

# 1b. Se é container app
docker top app

# 1c. Se é node_exporter ou outro
docker top node_exporter
```

### ✅ REMEDIAÇÃO (Nível 2: Otimizar)

**Se é aplicação:**

```bash
# Possíveis causas:
# - Loop infinito
# - Garbage collection pesada (Java)
# - Query SQL sem índice
# - Computação intensa

# Soluções:
# a) Restart gracioso
docker compose restart app

# b) Kill processo runaway (se identificado)
docker exec app kill -9 <PID>

# c) Se persistente, escalar (Nível 3)
```

**Se é infraestrutura (prometheus, etc):**

```bash
# Possíveis causas:
# - Muitas queries complexas
# - Scrape mal configurado
# - Retenção de dados alta

# Solução: reduzir carga
# Editar prometheus.yml: scrape_interval
```

### ✅ REMEDIAÇÃO (Nível 3: Scale)

```bash
# Se CPU não cai, aumentar recursos disponíveis

# Opção A: Aumentar limites do container
docker compose down app
# Editar docker-compose.yml:
#   resources:
#     limits:
#       cpus: '2'  # aumentar de 1
docker compose up -d app

# Opção B: Scale horizontal
docker compose up --scale app=3 -d
# (requer load balancer)
```

### ⚠️ Atenção

Não é alerta crítico, mas observar:
- Se latency_p99 também sobe → problema sério
- Se memory também alta → possível memory leak + CPU swap

---

## RUNBOOK — High CPU Critical

### 🔴 Alerta
```
Alertname:  HighCpuCritical
Severity:   CRITICAL 🔴
Condição:   CPU > 95% por mais de 1 minuto
SLA Impact: VIOLAÇÃO IMINENTE do SLO
```

### 🔍 DETECÇÃO

Alerta crítico = resposta **IMEDIATA** dentro de 5 minutos

### ✅ REMEDIAÇÃO (Ordem de Urgência)

**Ação 1: Parar Stress Imediato (30s)**

```bash
# Se sabido que é teste
pkill -f stress-ng
docker compose restart app

# Verificar
sleep 10
curl http://localhost:8080/health
```

**Ação 2: Kill Processo Runaway (1 min)**

```bash
# Identificar culpado
docker stats --no-stream
ps aux --sort=-%cpu

# Kill
docker exec <container> kill -9 <PID>
# OU
docker compose kill <service>
docker compose up -d <service>
```

**Ação 3: Listar Recursos (2 min)**

```bash
# Ver se há limite de CPU
docker inspect app | grep -A 10 "HostConfig"

# Se não há limite: Docker vai consumir 100% de um core
# Solução: adicionar limites em docker-compose.yml
```

**Ação 4: Scale (3 min)**

```bash
# Se não conseguir resolver, distribuir carga
docker compose up --scale app=3 -d

# Rotear requisições entre instâncias
# (nginx, haproxy, ou Azure LB)
```

**Ação 5: Escalação 🚨 (4 min)**

```bash
# Se nada funciona em < 5min:
# ESCALATE → Senior SRE / Platform Team

# Notificar em Slack channel #sre-incidents
# Ativar "Incident Commander"
```

---

## RUNBOOK — Low Memory Available

### 🔴 Alerta
```
Alertname:  LowMemoryAvailable
Severity:   CRITICAL 🔴
Condição:   Memória disponível < 10% por 2 minutos
SLA Impact: Sistema pode fazer OOM Kill
```

### 🔍 DIAGNÓSTICO (1-2 min)

```bash
# Memória atual
free -h

# Containers e seus usos
docker stats --no-stream

# Processos top consumers
ps aux --sort=-%mem | head -10

# Verificar se há swap
cat /proc/sys/vm/swappiness  # se > 0, está usando swap
```

### ✅ REMEDIAÇÃO

**Ação 1: Identificar Culpado (1 min)**

```bash
# Ver uso por container
docker stats --no-stream | sort -k4 -rh

# Se app está com >50% MEM:
# Possível memory leak, restart

docker compose restart app
```

**Ação 2: Liberar Memória (2 min)**

```bash
# Parar container desnecessário
docker compose stop prometheus
# (ou outro não crítico)

# Limpar volumes não usados
docker volume prune -f

# Limpar images
docker image prune -f
```

**Ação 3: Se Problema Persiste (3 min)**

```bash
# Aumentar swap
sysctl -w vm.swappiness=60

# Ou adicionar memória ao host/VM (se cloud)
# AWS/Azure: upgrade instance type
```

**Ação 4: Investigar Memory Leak (5 min)**

```bash
# Se sempre crescendo em app:
# Possível vazamento de memória

# Técnicas:
# 1. Jiff if Java: jmap -histo <PID>
# 2. Se Node: node --inspect app.js
# 3. Coletar heap dump para análise

# Rollback para versão anterior (se recém deployado)
```

---

## RUNBOOK — High Error Rate

### 🟡 Alerta
```
Alertname:  HighErrorRate
Severity:   WARNING 🟡
Condição:   Erros 5xx > 5% por 5 minutos
SLA Impact: Error Rate SLO violado (< 0.5% target)
```

### 🔍 DIAGNÓSTICO (3-5 min)

```bash
# 1. Confirmar taxa de erro
# Prometheus Query:
# (sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) * 100

# 2. Ver logs de erro
docker compose logs --tail=200 app | grep -i "error\|500\|exception"

# 3. Qual endpoint está falhando?
# Query: rate(http_requests_total{status="500"}[5m]) by (endpoint)

# 4. Erro específico?
grep "500" app_logs.txt | tail -20
```

### ✅ REMEDIAÇÃO

**Nível 1: Identificar Padrão**

```bash
# Qual endpoint?
# - /api/users → possível problema no DB
# - /api/payments → possível problema em serviço externo
# - Todas endpoints → possível crash geral

# Se crash geral:
docker compose restart app
```

**Nível 2: Investigar Dependência**

```bash
# Se erro específico de endpoint:
# Pode ser serviço externo

# Ex: /api/payments falha
# Verificar:
curl -v https://payment-provider-api.com/health

# Se down: não há o que fazer (dependência)
# Notificar stakeholders

# Se up: problema na integração
# Revisar logs, código, conexão
```

**Nível 3: Throttle/Circuit Breaker**

```bash
# Se problema é intermitente:
# Ativar circuit breaker no código

# Via env var (se implementado):
docker compose exec app \
  env CIRCUIT_BREAKER=enabled bash -c "..."

# Isso retorna erro 503 (Service Unavailable)
# em vez de 500 (Internal Server Error)
```

**Nível 4: Feature Flag**

```bash
# Se novo feature está causando erros:
# Desativar via feature flag

# Via env var:
docker compose stop app
docker compose exec app env NEW_FEATURE=disabled bash
docker compose start app
```

**Nível 5: Rollback**

```bash
# Se tudo falhar:
# Reverter para versão anterior

docker compose down app
# Editar docker-compose.yml → image tag anterior
docker compose up -d app

# Verificar se taxa de erro cai
```

---

## RUNBOOK — High Latency P99

### 🟡 Alerta
```
Alertname:  HighLatencyP99
Severity:   WARNING 🟡
Condição:   P99 latência > 1 segundo por 5 minutos
SLA Impact: Latency SLO violado (< 500ms target)
```

### 🔍 DIAGNÓSTICO (3-5 min)

```bash
# 1. Confirmar latência
# Prometheus:
# histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# 2. Comparar percentis
# P50: histogram_quantile(0.50, ...)  # median
# P95: histogram_quantile(0.95, ...)
# P99: histogram_quantile(0.99, ...)  # tail latency

# 3. Qual endpoint é lento?
# Query: histogram_quantile(0.99, ...) by (endpoint)

# 4. Começou de repente?
# Verificar: houve deploy? mudança de carga?
```

### ✅ REMEDIAÇÃO

**Nível 1: Gargalo de CPU**

```bash
# Se CPU está high também (> 80%):
# Ver RUNBOOK — High CPU Warning
# Likely causa: CPU bottleneck → latência sobe
```

**Nível 2: Gargalo de Banco de Dados**

```bash
# Se endpoint específico lento:
# ex: /api/users?full=true

# Possível: query SQL lenta
# Solução:
# - Adicionar índice no DB
# - Adicionar cache
# - Paginar resultados

# Verificar tempo de DB:
docker compose logs app | grep "query_time"
```

**Nível 3: Gargalo de Rede**

```bash
# Se latência para serviço externo:
# ex: GET https://api.external.com

# Possível: network latency, servidor lento
# Solução:
# - Timeout mais curto
# - Cache response
# - Retry com backoff

# Validar conectividade:
docker exec app ping -c 5 api.external.com
```

**Nível 4: Cache/Otimização**

```bash
# Se causa é carga alta:

# Redis cache (se disponível)
export REDIS_ENABLED=true

# Ou reduzir precision de resultado
docker compose restart app
```

---

## RUNBOOK — Prometheus Down

### 🔴 Alerta
```
Alertname:  PrometheusDown
Severity:   CRITICAL 🔴
Condição:   up{job="prometheus"} == 0 por 1 minuto
SLA Impact: TODO o monitoramento comprometido!
```

### 🔍 DIAGNÓSTICO (1 min)

```bash
# Prometheus está rodando?
docker compose ps prometheus

# Ver logs
docker compose logs prometheus
```

### ✅ REMEDIAÇÃO (URGENTE!)

```bash
# Restart IMEDIATO
docker compose restart prometheus

# Aguardar 10s
sleep 10

# Validar
curl http://localhost:9090/-/healthy

# Se erro persistir:
docker compose logs -f prometheus

# Problemas comuns:
# - /prometheus volume cheio:
#   du -sh /prometheus
# - Config inválido:
#   docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
# - Port já em uso:
#   lsof -i :9090
```

---

## 📞 Escalation Matrix

| Tipo | Tempo | Ação |
|------|--------|------|
| 🔴 CRITICAL | T+1min | Slack notify + resolver |
| 🔴 CRITICAL | T+5min | Escalate → Senior SRE |
| 🔴 CRITICAL | T+15min | Incident Commander |
| 🟡 WARNING | T+10min | Investigar |
| 🟡 WARNING | T+30min | Escalate → Team Lead |

---

## 🔗 Recursos Úteis

| Recurso | Link |
|---------|------|
| Dashboard | http://grafana:3000 |
| Prometheus | http://prometheus:9090 |
| Alertmanager | http://alertmanager:9093 |
| Logs | `docker compose logs -f` |
| Metrics | `docker exec prometheus promtool` |

---

## 📝 Notas

- **Sempre documentar** no POST_MORTEM_TEMPLATE.md
- **Comunicar progresso** em #sre-incidents
- **Não hésitar em escalar** se não resolvido em 5 min
- **Testar runbook** periodicamente (drills mensais)

---

**Última atualização**: 20 de abril de 2026  
**Próxima revisão**: 20 de maio de 2026  
**Mantido por**: Platform / SRE Team
