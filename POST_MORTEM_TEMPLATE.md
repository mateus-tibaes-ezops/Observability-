# POST-MORTEM DE INCIDENTE

**ID do Incidente**: [YYYYMMDD-HHMM ou Ticket #]  
**Data do Incidente**: [YYYY-MM-DD]  
**Data do Post-Mortem**: [YYYY-MM-DD]  
**Duração do Incidente**: [HHmm - Total de downtime]  
**Severidade**: 🔴 CRÍTICO / 🟡 ALTO / 🟢 MÉDIO

---

## 📋 PARTICIPANTES

| Papel | Nome | Email |
|-------|------|-------|
| Incident Commander | | |
| On-Call SRE | | |
| Engineering Lead | | |
| Product Manager | | |

---

## 📊 RESUMO EXECUTIVO

**Uma frase que resume o incidente:**

[Ex: "A aplicação estava indisponível por 45 minutos devido ao esgotamento de memória causado por um memory leak em uma nova versão deployada."]

**Impacto:**
- ❌ Clientes afetados: [%]
- ⏱️ Tempo de resposta (detecção → mitigação): [minutos]
- 💰 Impacto financeiro estimado: [R$ ou % do SLA]
- 📊 Requisições perdidas/falhadas: [número]

**Resultado Final:**
- ✅ Serviço restaurado? Sim / Não
- ⚠️ SLO violado? Sim (Availability [%]) / Não
- 📈 SLI ao final: Availability [%], Error Rate [%], Latency P99 [ms]

---

## 🕐 TIMELINE (do Incidente)

| Horário | Evento | Responsável | Detalhes |
|---------|--------|-------------|----------|
| HH:MM:SS | Alerta dispara | Prometheus | ServiceDown crítico |
| HH:MM:SS | Detecção | On-call SRE | Notificação Slack recebida |
| HH:MM:SS | Investigação | SRE | Verificar logs, containers |
| HH:MM:SS | Root cause identificado | SRE | Memory leak em v2.1.0 |
| HH:MM:SS | Mitigação iniciada | SRE | Restart container |
| HH:MM:SS | Mitigação completa | SRE | App online, up == 1 |
| HH:MM:SS | Verificação | SRE | Métricas normalizadas |
| HH:MM:SS | Comunicação | PM | Status page atualizada |
| HH:MM:SS | Monitoramento pós-incidente | SRE | Observar próximas 1h |

**Total: [X min] de incidente ativo**

---

## 🔍 ANÁLISE DE CAUSA RAIZ (RCA)

### 1. O Que Aconteceu? (Fato)

Descrever exatamente o que foi observado:
- Métrica que violou SLO: `up{job="application"}` foi de 1 → 0
- Duração: 45 minutos
- Scope: Apenas aplicação, não afetou Prometheus/Grafana

### 2. Por Que Aconteceu? (Causa Raiz)

**Causa Primária:**

[Ex: "Versão v2.1.0 continha um memory leak na função handleCache() que crescia indefinidamente, causando OOM Kill do container após ~30 minutos de operação."]

**Causa Raiz (5 Whys):**

1. **Por que app crashou?** → OOM Kill
2. **Por que OOM Kill?** → Memory cresceu para 2GB+ (limite 1GB)
3. **Por que memory cresceu?** → Não estava sendo liberada em cache
4. **Por que cache não libera?** → Bug na função handleCache() - sem TTL
5. **Por que bug não foi detectado?** → Testes de load não cobrem esse cenário

**Causa Raiz:** Falta de testes de carga para scenarios de longa duração (> 30min)

### 3. Causas Contribuintes

- ❌ Falta de memory limits alerting (antes de OOM)
- ❌ Testes de load insuficientes
- ❌ Rollout gradual não foi usado (100% traffic de uma vez)
- ❌ Baseline de memory não documentado

### 4. Fatores que Agravaram

- ⚠️ Horário de pico de tráfego (accelerou consumo de memória)
- ⚠️ Sem circuit breaker (não degradou gracefully)
- ⚠️ Sem auto-rollback trigger

### 5. Possíveis Modos de Falha Não Explorados

- [ ] Latência alta causando retry storms
- [ ] Connection pool exhaustion
- [ ] Database connection leak
- [ ] Cache hit ratio degradation

---

## ✅ MITIGAÇÃO (O que foi feito)

### Ação Tomada

1. **Restart container (T+3min)**
   - Comando: `docker compose restart app`
   - Efeito: Temporário, problema reaparece após 30min
   - Resultado: Não foi solução permanente

2. **Rollback para v2.0.5 (T+15min)**
   - Comando: Editar docker-compose.yml, remove v2.1.0
   - Tempo de deploy: 2 minutos
   - Resultado: ✅ Serviço estável após rollback

3. **Monitoramento contínuo (T+15min até T+75min)**
   - Observar memory usage a cada 5 min
   - Alertas configurados para LowMemoryAvailable
   - Resultado: ✅ Nenhum problema adicional

### Por que essa solução resolveu?

v2.0.5 não contém o bug de memory leak, então memory stays stable.

---

## 🚀 AÇÕES CORRETIVAS (Prevenir Recorrência)

### Correções Imediatas (Fazer em 1 semana)

- [ ] **AC1**: Fix memory leak em handleCache() - PR review + merge
  - Owner: Dev Lead
  - Prazo: 2026-04-27
  - Validar: Deploy em staging, rodar load test 2h, validar memory

- [ ] **AC2**: Adicionar memory limit alert antes de OOM
  - Owner: SRE
  - Prazo: 2026-04-25
  - Alert: LowMemoryAvailable (já existe em alerts.rules.yml)
  - Tuning: Alertar em 60% utilização (antes de 90%)

- [ ] **AC3**: Implementar auto-rollback em deploy
  - Owner: DevOps
  - Prazo: 2026-04-30
  - Trigger: Se error_rate > 5% nos primeiros 2min pós-deploy
  - Script: scripts/auto-rollback.sh

### Melhorias a Curto Prazo (1-2 meses)

- [ ] **AC4**: Testes de load de longa duração (6h minimum)
  - Owner: QA + SRE
  - Frequency: Rodai antes de cada major release
  - Tool: k6 com cenário de longa duração

- [ ] **AC5**: Implementar circuit breaker na aplicação
  - Owner: Backend Team
  - Target SLI: Erro graceful (503) vs hard error (500)

- [ ] **AC6**: Documentar baseline de recursos por versão
  - Owner: SRE + Dev
  - Format: Arquivo resource_baseline.md
  - Atualizar: Cada major release

- [ ] **AC7**: Implementar canary deployment (5% traffic primeiro)
  - Owner: DevOps
  - Timeline: Antes do próximo deploy
  - Tool: Kubernetes canary ou AWS traffic shifting

### Melhorias a Longo Prazo (3-6 meses)

- [ ] **AC8**: Blue/Green deployment setup
  - Owner: Platform Team
  - Benefício: Zero-downtime deployments

- [ ] **AC9**: Memory profiling contínuo (async profiler)
  - Owner: SRE + Dev
  - Ferramenta: Prometheus + async-profiler exporter

- [ ] **AC10**: Litmus chaos tests
  - Owner: SRE
  - Frequency: Semanal
  - Cenários: Memory pressure, CPU spike, network partition

---

## 📈 MÉTRICAS DE IMPACTO

### Antes do Incidente

```
Availability SLO (target: 99.5% / mês)
├─ Uptime acumulado: 99.8%
├─ Métrica: up == 1 (100% do tempo)
└─ Status: ✅ OK

Latency SLO (target: P99 < 500ms)
├─ P99 atual: 120ms
├─ Status: ✅ OK

Error Rate SLI (target: < 0.5%)
├─ Taxa 5xx: 0.01%
└─ Status: ✅ OK
```

### Durante o Incidente

```
Availability SLO
├─ Uptime: 0% (app down por 45min)
├─ Cumulative: 99.68% (violated!)
└─ Status: ❌ VIOLADO

Latency SLO
├─ P99: ∞ (requests timeouts)
└─ Status: ❌ VIOLADO

Error Rate SLI
├─ Taxa 5xx: 100% (todas requisições falharam)
└─ Status: ❌ VIOLADO
```

### Depois da Mitigação

```
Availability SLO
├─ Uptime: 100% (após rollback)
├─ Cumulative: 99.5%
└─ Status: ⚠️ NO LIMITE (recovered)

Latency SLO
├─ P99: 130ms (recuperado)
└─ Status: ✅ NORMALIZADO

Error Rate SLI
├─ Taxa 5xx: 0.01% (recuperada)
└─ Status: ✅ NORMALIZADO
```

### Custo Estimado

- Serviço down: 45 minutos
- Taxa de requisições: ~1000 RPS
- Requisições perdidas: 45 × 60 × 1000 = 2.7M requisições
- % de clientes impactados: ~15% (aqueles com retry timeouts curtos)
- Impacto financeiro: [Estimado em base de receita/min]

---

## 💡 LIÇÕES APRENDIDAS

### O Que Funcionou Bem ✅

1. **Alerta rápido**: Detecção em < 1 minuto
   - Prometheus alertas bem configurados
   - Slack integração funcionando
   - On-call SRE respondeu rápido

2. **Resposta estruturada**: Seguir runbook acelerou resolução
   - Passos de diagnóstico bem claros
   - Equipe sabia o que fazer (rollback)

3. **Observabilidade**: Métricas mostraram exatamente o problema
   - Memory usage visível em Grafana
   - Logs tinham informação sobre OOM

### O Que Não Funcionou ❌

1. **Testes de load inadequados**
   - Não cobria duração > 30 min
   - Não detectou memory leak

2. **Falta de memory limits alerting**
   - Esperou até OOM, ideal seria alertar em 60%

3. **Rollout strategy**
   - 100% de traffic em nova versão
   - Deveria ter sido canary (5% primeiro)

4. **Comunicação com clientes**
   - Status page não atualizada instantaneamente
   - Clientes não sabiam o que estava happening

### O Que Poderia Ser Melhor 🔄

1. **Pre-deployment validation**
   - Profiling de memory obrigatório
   - Load test checklist antes de deploy

2. **Automated remediation**
   - Auto-rollback não estava implementado
   - Poderia ter resolvido em < 1 min

3. **Incident drill**
   - Última simulação foi há 3 meses
   - Equipe poderia estar mais preparada

---

## 📚 REFERÊNCIAS & RECURSOS

### Documentação Interna

- [RUNBOOK.md](RUNBOOK.md) - Procedimentos de resposta (já existente)
- [VERIFICACAO.md](VERIFICACAO.md) - Checklist de verificação
- [README.md](README.md) - Definição de SLOs/SLIs

### Monitoring & Alerting

- Prometheus: http://prometheus:9090
- Grafana: http://grafana:3000
- Alertmanager: http://alertmanager:9093

### Tools Úteis

```bash
# Ver histórico de deploys
docker image ls app
git log --oneline app/ | head -20

# Análise de memory
docker stats app --no-stream

# Check resource limits
docker inspect app | grep -A 20 "HostConfig"
```

---

## ✍️ APROVAÇÃO

| Papel | Nome | Data | Assinatura |
|-------|------|------|-----------|
| Incident Commander | | | |
| Engineering Lead | | | |
| SRE Lead | | | |
| Product Manager | | | |

---

## 📌 FOLLOW-UP

### Próxima Reunião

- Data: [YYYY-MM-DD]
- Participantes: [Mesma equipe]
- Agenda: Revisar status das ações corretivas

### Tracking das Ações

Ver planilha: [Link para spreadsheet de tracking]

---

## 📖 Versão do Documento

| Versão | Data | Alterações |
|--------|------|-----------|
| 1.0 | 2026-04-20 | Versão inicial |
| 1.1 | [data] | [Mudanças] |

---

**Confidencial - Apenas para equipe interna**  
**Não compartilhar com clientes sem aprovação**  
**Reter por mínimo 1 ano para auditoria**
