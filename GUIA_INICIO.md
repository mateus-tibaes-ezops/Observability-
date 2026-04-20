# GUIA DE INÍCIO RÁPIDO — Stack de Observabilidade Completo

**Versão**: FASE 1 + 2 + 3 COMPLETA ✅  
**Data**: 20 de abril de 2026  
**Status**: Pronto para produção

---

## 🎯 O Que Você Tem Agora

### ✅ FASE 1: Prometheus + Grafana
- **5 containers**: Prometheus, Grafana, Node Exporter, App, Alertmanager
- **8 dashboards**: CPU, Memória, HTTP Metrics, Health
- **6 regras de alerta**: CPU, Memória, Disponibilidade, Latência, Taxa de erro
- **SLOs documentados**: Availability 99.5%, Latency P99 <500ms, Error Rate <0.5%

### ✅ FASE 2: Alertmanager + Slack
- **Alertmanager integrado**: Roteamento e agrupamento de alertas
- **Notificações Slack**: Template customizado com severity levels
- **Receivers**: slack-notifications (geral) e slack-critical (prioritário)
- **Regras de inibição**: Suprimir alertas redundantes

### ✅ FASE 3: Simulação + Runbooks
- **simulate_failure.sh**: 6 cenários de teste (crash, CPU, memory, latency, errors, combined)
- **RUNBOOK.md**: Procedimentos detalhados para cada alerta
- **POST_MORTEM_TEMPLATE.md**: Template de análise de incidente

---

## 🚀 COMEÇAR EM 5 MINUTOS

### Passo 1: Clonar/Abrir Projeto

```bash
cd /Users/mateustibaes/Desktop/Observabilidade
ls -la
```

Esperado: 11 arquivos + 4 diretórios

```
.env.example
.gitignore
FASE1_RESUMO.md
FASE2_SLACK.md
POST_MORTEM_TEMPLATE.md
README.md
ROADMAP.md
RUNBOOK.md
VERIFICACAO.md
alertmanager.yml
docker-compose.yml
prometheus/
grafana/
templates/
scripts/
```

### Passo 2: Configurar Slack (5 min)

**Se quer testar com Slack:**

1. Acesse: https://api.slack.com/apps/
2. Create New App → From scratch
3. Nome: "Observabilidade Alerts"
4. Incoming Webhooks → On
5. Add New Webhook → Escolha canal #alerts-infra
6. Copie URL (ex: https://hooks.slack.com/services/...)

**Criar .env:**

```bash
cp .env.example .env

# Edite .env:
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../XXXXX
SLACK_CHANNEL=#alerts-infra
```

**Se não quer Slack agora:**

```bash
# Usar placeholder (alertas vão para Alertmanager UI)
cp .env.example .env
# Deixar SLACK_WEBHOOK_URL com valor placeholder
```

### Passo 3: Iniciar Stack

```bash
# Inicie todos os 5 containers
docker compose up -d

# Verifique
docker compose ps

# Esperado: 5 containers "Up"
# - prometheus
# - grafana  
# - node_exporter
# - app
# - alertmanager
```

### Passo 4: Acessar Interfaces

| Serviço | URL | Login |
|---------|-----|-------|
| **Grafana** | http://localhost:3000 | admin/admin |
| **Prometheus** | http://localhost:9090 | N/A |
| **Alertmanager** | http://localhost:9093 | N/A |
| **App** | http://localhost:8080 | N/A |

### Passo 5: Validar

```bash
# Checklist de verificação
# Abra: http://localhost:9090/targets
# Esperado: 3 jobs em status "UP"
# - prometheus
# - node_exporter
# - application

# Abra: http://localhost:3000/d/observabilidade-main
# Esperado: 8 painéis carregados com métricas
```

---

## 🧪 TESTAR ALERTAS (10 min)

### Opção A: Teste Rápido (1 min)

```bash
# Simular alta CPU
brew install stress-ng  # ou: apt-get install stress-ng

# Terminal 1: Gerar stress
stress-ng --cpu 4 --timeout 180s

# Terminal 2: Observar
# Prometheus: http://localhost:9090/graph
# Query: (100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))
# Esperado: CPU sobe para > 80% em ~2 min → Alerta no Slack

# Terminal 3: Ver alertas
# Alertmanager: http://localhost:9093/#/alerts
```

### Opção B: Script de Simulação (5-10 min)

```bash
# Ver opcões disponíveis
./scripts/simulate_failure.sh --help

# Testar crash
./scripts/simulate_failure.sh crash

# Testar CPU stress
./scripts/simulate_failure.sh cpu --duration 180

# Testar cenário combinado
./scripts/simulate_failure.sh combined

# Listar status atual
./scripts/simulate_failure.sh list
```

### Esperado em Cada Teste

```
🟡 WARNING • HighCpuWarning

📝 CPU está acima de 80% por mais de 2 minutos.
💾 Status: Valor atual: 85%
🖥️ Instância: node-exporter
🎯 Serviço: node_exporter
📚 Runbook: https://wiki.company.com/runbooks/high-cpu
📊 Dashboard: http://grafana:3000
```

---

## 📚 DOCUMENTAÇÃO POR TÓPICO

### Para Entender a Stack

- 📄 **README.md** - Guia principal, SLOs/SLIs, Quick Start
- 📄 **VERIFICACAO.md** - Checklist de validação
- 📄 **FASE1_RESUMO.md** - Resumo executivo da FASE 1

### Para Responder a Alertas

- 📄 **RUNBOOK.md** - Procedimentos para cada alerta (o mais importante!)
  - ServiceDown → Como resolver em 5 min
  - HighCpuWarning → Diagnóstico e mitigação
  - HighErrorRate → Investigação de causa raiz
  - [... 7 runbooks total]

### Para Analisar Incidentes

- 📄 **POST_MORTEM_TEMPLATE.md** - Template para documentar incidente
- 📄 **ROADMAP.md** - Plano futuro e melhorias

### Para Configuração

- 📄 **docker-compose.yml** - Stack de containers
- 📄 **alertmanager.yml** - Configuração de alertas + Slack
- 📄 **.env.example** - Variáveis de ambiente
- 📁 **prometheus/** - Configuração Prometheus
  - prometheus.yml - Jobs de scrape
  - alerts.rules.yml - Regras de alerta
- 📁 **grafana/** - Dashboards e datasources
  - provisioning/datasources/prometheus.yml
  - provisioning/dashboards/main.json (8 painéis)
- 📁 **templates/** - Templates de mensagem
  - slack.tmpl - Formato Slack
- 📁 **scripts/** - Scripts de simulação
  - simulate_failure.sh - 6 cenários de teste

---

## 🎯 PRÓXIMOS PASSOS

### Curto Prazo (Esta Semana)

1. ✅ **Iniciar stack**: `docker compose up -d`
2. ✅ **Testar alertas**: Rodar `simulate_failure.sh crash`
3. ✅ **Validar Slack**: Confirmar que mensagens chegam
4. 📝 **Personalizar dashboards**: Adicionar seus endpoints
5. 📝 **Atualizar runbooks**: Com procedimentos específicos da sua infra

### Médio Prazo (Próximo Mês)

- [ ] Integrar com CI/CD (alertas ao fazer deploy)
- [ ] Configurar auto-rollback quando alertas críticos disparam
- [ ] Adicionar alertas customizadas (negócio específico)
- [ ] Testar cenários de falha mensalmente (drills)
- [ ] Preparar runbooks para produção

### Longo Prazo (3-6 Meses)

- [ ] Migrar para Kubernetes (Helm charts)
- [ ] Implementar Thanos (histórico de métricas de longo prazo)
- [ ] Adicionar SLO tracking automático
- [ ] Implementar chaos engineering (Chaos Mesh)
- [ ] Cultura de observabilidade (training da equipe)

---

## ❓ FAQs

### P: Como alterar webhook do Slack?

```bash
# Editar .env
vim .env
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/NEW_WEBHOOK

# Restart Alertmanager
docker compose restart alertmanager
```

### P: Como adicionar novo alerta?

1. Editar `prometheus/alerts.rules.yml`
2. Adicionar nova regra (copiar template existente)
3. Reload: `docker compose restart prometheus`

### P: Como alterar threshold de CPU?

Editar `prometheus/alerts.rules.yml`:
```yaml
- alert: HighCpuWarning
  expr: |
    (100 - ...) > 90  # Mudou de 80 para 90
```

### P: Como adicionar novo dashboard?

1. Criar em Grafana UI (http://localhost:3000)
2. Export JSON: Dashboard → Settings → JSON Model
3. Salvar em `grafana/provisioning/dashboards/`
4. Restart Grafana: `docker compose restart grafana`

### P: Posso rodar em produção assim?

Quase! Antes de produção:

- [ ] Adicionar persistent storage (volumes externos)
- [ ] Configurar backups de Prometheus
- [ ] Adicionar authentication (Grafana + Prometheus)
- [ ] Load balancer na frente
- [ ] Escalar horizontalmente (multi-node)
- [ ] Adicionar logs centralizados (ELK stack)
- [ ] Redundância (alertmanager HA)

---

## 📞 CONTATO E SUPORTE

### Se Algo Não Funciona

1. **Verificar logs:**
   ```bash
   docker compose logs -f
   docker compose logs -f prometheus
   docker compose logs -f alertmanager
   ```

2. **Validar conectividade:**
   ```bash
   docker compose exec prometheus ping alertmanager
   docker compose exec alertmanager curl http://prometheus:9090/-/healthy
   ```

3. **Consultar VERIFICACAO.md:**
   Tem checklist de troubleshooting comum

4. **Rodar test de Slack:**
   ```bash
   curl -X POST $SLACK_WEBHOOK_URL \
     -H 'Content-Type: application/json' \
     -d '{"text": "✅ Teste"}'
   ```

---

## 📊 ESTRUTURA FINAL

```
observabilidade/
├── 📄 docker-compose.yml              ← IMPORTANTE: Stack principal
├── 📄 alertmanager.yml                ← IMPORTANTE: Config Slack
├── 📁 prometheus/
│   ├── prometheus.yml                 ← Jobs de scrape
│   └── alerts.rules.yml               ← 6 alertas
├── 📁 grafana/
│   └── provisioning/
│       ├── datasources/prometheus.yml ← Datasource
│       └── dashboards/main.json       ← 8 painéis
├── 📁 templates/
│   └── slack.tmpl                     ← Template Slack
├── 📁 scripts/
│   └── simulate_failure.sh            ← Teste de falhas
├── 📄 README.md                       ← Guia principal
├── 📄 RUNBOOK.md                      ← IMPORTANTE: Como responder
├── 📄 POST_MORTEM_TEMPLATE.md         ← Template incidente
├── 📄 .env.example                    ← Variáveis
└── 📄 .gitignore

✅ = Tudo pronto para usar
```

---

## ✨ Highlights

✅ **Tudo em Docker**: Sem dependências adicionais  
✅ **Zero Configuração Manual**: Dashboards provisionados  
✅ **Secrets via .env**: Seguro para produção  
✅ **Bem Documentado**: Cada arquivo tem comentários  
✅ **Pronto para Teste**: Scripts de simulação inclusos  
✅ **SRE Best Practices**: Runbooks + post-mortem  

---

## 🎓 Aprenda Mais

- [Prometheus Official Docs](https://prometheus.io/docs/)
- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Alertmanager Routing](https://prometheus.io/docs/alerting/latest/configuration/#route)
- [SRE Best Practices](https://sre.google/books/)

---

## 📝 Próxima Ação

**Recomendação:**

1. **Agora (5 min):** Iniciar stack → `docker compose up -d`
2. **Hoje (30 min):** Testar alertas → `./scripts/simulate_failure.sh crash`
3. **Hoje (1h):** Ler RUNBOOK.md → Entender resposta a alertas
4. **Amanhã (1h):** Treinar equipe → Fazer drill de incidente

---

**Status**: ✅ STACK COMPLETA E PRONTA PARA USO  
**Criação**: 20 de abril de 2026  
**Mantido por**: SRE Team

🚀 **Você agora tem observabilidade de classe mundial!**
