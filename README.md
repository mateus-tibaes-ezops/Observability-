# Stack de Observabilidade e Resiliência - FASE 1

**Status**: ✅ Prometheus + Grafana configurados

## 📋 Visão Geral

Este projeto implementa uma stack completa de observabilidade baseada em **Prometheus** e **Grafana**, com alertas automatizados e dashboards provisionados.

### Componentes

- **Prometheus**: Coleta centralizada de métricas (15s de intervalo)
- **Grafana**: Visualização e dashboards (porta 3000)
- **Node Exporter**: Métricas de infraestrutura (CPU, memória, disco)
- **Application**: Serviço de exemplo com endpoint `/metrics`

---

## 🚀 Quick Start

### 1. Pré-requisitos

- Docker & Docker Compose instalados
- Portas livres: 3000 (Grafana), 9090 (Prometheus), 9100 (Node Exporter), 8080 (App)

### 2. Iniciar a Stack

```bash
# Clone ou navegue ao diretório do projeto
cd /Users/mateustibaes/Desktop/Observabilidade

# Inicie todos os serviços
docker compose up -d

# Verifique o status
docker compose ps
```

### 3. Acessar Interfaces

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| **Grafana** | http://localhost:3000 | admin / admin |
| **Prometheus** | http://localhost:9090 | N/A (sem auth) |
| **Node Exporter** | http://localhost:9100 | N/A |
| **Application** | http://localhost:8080 | N/A |

### 4. Parar a Stack

```bash
docker compose down

# Com limpeza de volumes
docker compose down -v
```

---

## 📊 SLOs e SLIs

### Availability SLO
- **Target**: 99.5% uptime/mês (máx. ~3.6 horas de downtime)
- **SLI**: Métrica `up{job="application"}` == 1
- **Alerta**: `ServiceDown` → crítico após 30 segundos

### Latency SLO
- **Target**: P99 < 500ms para 95% das requisições
- **SLI**: `histogram_quantile(0.99, http_request_duration_seconds_bucket)` < 0.5s
- **Alerta**: `HighLatencyP99` → warning após 5 minutos

### Error Rate SLI
- **Target**: < 0.5% de erros 5xx
- **SLI**: `sum(5xx errors) / sum(total requests)` < 0.005
- **Alerta**: `HighErrorRate` → warning quando > 5% por 5 minutos

---

## ⚠️ Alertas Configurados

### Infraestrutura

| Alerta | Condição | Severidade | Ação |
|--------|----------|-----------|------|
| **HighCpuWarning** | CPU > 80% por 2min | ⚠️ Warning | Monitorar |
| **HighCpuCritical** | CPU > 95% por 1min | 🔴 Critical | Intervenção imediata |
| **LowMemoryAvailable** | Memória < 10% por 2min | 🔴 Critical | Intervenção imediata |

### Aplicação

| Alerta | Condição | Severidade | Ação |
|--------|----------|-----------|------|
| **ServiceDown** | up == 0 por 30s | 🔴 Critical | Restart/Rollback |
| **HighErrorRate** | Erros 5xx > 5% por 5min | ⚠️ Warning | Investigar logs |
| **HighLatencyP99** | P99 > 1s por 5min | ⚠️ Warning | Investigar gargalo |

### Monitoramento

| Alerta | Condição | Severidade | Ação |
|--------|----------|-----------|------|
| **PrometheusDown** | Prometheus down por 1min | 🔴 Critical | Restart monitoramento |

---

## 📁 Estrutura de Arquivos

```
observabilidade/
├── docker-compose.yml              # Definição de serviços
├── prometheus/
│   ├── prometheus.yml              # Config: jobs de scrape
│   └── alerts.rules.yml            # Regras de alertas
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── prometheus.yml      # Datasource Prometheus
│       └── dashboards/
│           └── main.json           # Dashboard principal
├── templates/                      # (FASE 2) Templates Slack
├── scripts/                        # (FASE 2/3) Scripts de teste
├── RUNBOOK.md                      # (FASE 2) Procedimentos
├── POST_MORTEM_TEMPLATE.md         # (FASE 3) Template de post-mortem
└── README.md                       # Este arquivo
```

---

## 🔧 Verificar Dados no Prometheus

1. Acesse **http://localhost:9090**
2. Explore métricas:
   - `node_cpu_seconds_total` (CPU)
   - `node_memory_MemAvailable_bytes` (Memória)
   - `http_requests_total` (Requisições HTTP)
   - `http_request_duration_seconds_bucket` (Latência)

### Exemplo: Cálculo de CPU

```promql
# CPU atual em %
(100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))
```

---

## 📈 Dashboards Grafana

### Dashboard Principal

Acesse: **http://localhost:3000/d/observabilidade-main**

**Painéis Inclusos:**

1. **CPU Usage (%)** - Gauge com thresholds (verde <70%, amarelo 70-85%, vermelho >85%)
2. **Memory Usage (%)** - Gauge com thresholds (verde <75%, amarelo 75-90%, vermelho >90%)
3. **CPU Usage Over Time** - Série temporal dos últimos 6 horas
4. **Memory Usage Over Time** - Série temporal dos últimos 6 horas
5. **HTTP Request Rate** - Taxa de requisições por segundo
6. **HTTP Error Rate (5xx)** - Taxa de erros com thresholds
7. **HTTP Latency (P50/P95/P99)** - Percentis de latência
8. **Service Health Status** - Tabela com status dos serviços

---

## 🔍 Troubleshooting

### Prometheus não conecta ao Node Exporter

```bash
# Verificar se container está rodando
docker compose ps node_exporter

# Verificar logs
docker compose logs node_exporter

# Testar conectividade
docker exec prometheus wget -O- http://node_exporter:9100
```

### Grafana não carrega datasource

```bash
# Verificar arquivo provisioning
ls -la grafana/provisioning/datasources/

# Reiniciar Grafana
docker compose restart grafana

# Verificar logs
docker compose logs grafana | grep datasource
```

### Métricas vazias no Prometheus

```bash
# Verificar se targets estão up
# Acesse: http://localhost:9090/targets

# Se aparecer erro, verificar:
# 1. Docker network configurada
# 2. Nome do host correto em prometheus.yml
# 3. Porta exposta corretamente
```

---

## ⚙️ Customização

### Alterar intervalo de scrape

Edite `prometheus/prometheus.yml` e modifique:

```yaml
global:
  scrape_interval: 30s  # Aumentar para 30s
```

Depois: `docker compose up -d prometheus`

### Adicionar novo endpoint para monitoramento

1. Edite `prometheus/prometheus.yml`
2. Adicione novo job em `scrape_configs`
3. Reinicie: `docker compose up -d prometheus`

### Alterar threshold de alerta

Edite `prometheus/alerts.rules.yml`:

```yaml
- alert: HighCpuWarning
  expr: |
    (100 - ...) > 90  # Mudou de 80 para 90
```

---

## 📝 Logs e Debug

```bash
# Todos os logs
docker compose logs -f

# Logs de um serviço específico
docker compose logs -f prometheus
docker compose logs -f grafana
docker compose logs -f node_exporter

# Últimas 50 linhas
docker compose logs --tail=50 prometheus
```

---

## 🔄 Próximas Fases

- **FASE 2**: Alertas via Slack + Alertmanager
- **FASE 3**: Simulação de falhas + Runbooks

---

## 📚 Referências

- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Node Exporter Metrics](https://github.com/prometheus/node_exporter)
- [Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)

---

**Última atualização**: 20 de abril de 2026  
**Versão**: FASE 1 ✅
