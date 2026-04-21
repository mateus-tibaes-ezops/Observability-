#!/bin/bash

# ============================================================
# SIMULATE_FAILURE.SH - Script para Simular Falhas
# ============================================================
# Simula diferentes cenários de falha para testar:
# - Alertas do Prometheus
# - Notificações Slack
# - Runbooks de resposta
# ============================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# FUNÇÕES AUXILIARES
# ============================================================

print_header() {
  echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================
# FUNÇÃO: Mostrar Ajuda
# ============================================================

show_help() {
  cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║         SIMULATE_FAILURE - Teste de Falhas                ║
║                                                            ║
║ Simula diferentes cenários para validar:                  ║
║  • Alertas do Prometheus                                  ║
║  • Notificações Slack                                     ║
║  • Métricas de observabilidade                           ║
╚════════════════════════════════════════════════════════════╝

OPÇÕES:

  crash              Simular crash da aplicação (kill container)
                     ├─ Alerta: ServiceDown (crítico)
                     ├─ Duração: 30s até restart automático
                     └─ Esperado: Mensagem Slack em 30s

  cpu                Simular alta CPU com container de stress
                     ├─ Alerta: HighCpuWarning (2min) 
                     ├─ Alerta: HighCpuCritical (1min @ 95%)
                     ├─ Duração: 3 minutos
                     └─ Esperado: 2 alertas no Slack

  memory             Simular pressão de memória
                     ├─ Alerta: LowMemoryAvailable
                     ├─ Duração: 2 minutos
                     └─ Esperado: Alerta crítico no Slack

  latency            Simular latência alta
                     ├─ Alerta: HighLatencyP99
                     ├─ Duração: 5 minutos
                     └─ Esperado: Warning no Slack

  errors             Injetar erros HTTP 500
                     ├─ Alerta: HighErrorRate
                     ├─ Duração: 5 minutos
                     └─ Esperado: Warning no Slack

  combined           Simular múltiplas falhas simultaneamente
                     ├─ Gera: CPU alta + Latência + Erros
                     ├─ Duração: 5 minutos
                     └─ Esperado: Agrupamento de alertas

  list               Listar containers e métricas atuais

  cleanup            Remover containers de teste

EXEMPLOS:

  ./scripts/simulate_failure.sh crash
  ./scripts/simulate_failure.sh cpu --duration 120
  ./scripts/simulate_failure.sh combined
  ./scripts/simulate_failure.sh list

OBSERVAÇÕES:

  • Todos os testes podem enviar notificações ao Slack e Discord
  • Verifique http://localhost:9090/graph para métricas
  • Verifique http://localhost:9093 para alertas
  • Cancelar script com Ctrl+C (alguns testes continuam rodando)

EOF
}

# ============================================================
# FUNÇÃO: Listar Status Atual
# ============================================================

list_status() {
  print_header "Status Atual da Stack"
  
  echo ""
  print_info "Containers:"
  docker compose ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "Docker não disponível"
  
  echo ""
  print_info "Principais URLs:"
  echo "  • Grafana:      http://localhost:3000"
  echo "  • Prometheus:   http://localhost:9090"
  echo "  • Alertmanager: http://localhost:9093"
  echo "  • App:          http://localhost:8080"
  
  echo ""
  print_info "Métricas Atuais (Prometheus):"
  curl -s 'http://localhost:9090/api/v1/query' --data-urlencode 'query=up' | jq '.data.result[] | {job: .metric.job, instance: .metric.instance, status: .value[1]}' 2>/dev/null || echo "  Não disponível"
  
  echo ""
  print_info "Alertas Ativos:"
  curl -s 'http://localhost:9090/api/v1/alerts' | jq '.data.alerts[] | {alertname: .labels.alertname, severity: .labels.severity, state: .state}' 2>/dev/null || echo "  Nenhum alerta ativo"
}

# ============================================================
# FUNÇÃO: OPÇÃO A - Crash da Aplicação
# ============================================================

simulate_crash() {
  print_header "Simulando CRASH da Aplicação"
  
  echo ""
  print_warning "Matando container 'app'..."
  docker compose kill app
  print_success "Container parado"
  
  echo ""
  print_info "Prometheus detectará: up{job='application'} == 0"
  print_info "Esperado: Alerta 'ServiceDown' (crítico) no Slack após 30s"
  
  echo ""
  read -p "Pressione ENTER para restaurar o serviço..." 
  
  print_warning "Restaurando container..."
  docker compose up -d app
  sleep 5
  print_success "App restaurado"
  
  echo ""
  print_info "Esperado: Alerta RESOLVIDO no Slack"
}

# ============================================================
# FUNÇÃO: OPÇÃO B - Alta CPU
# ============================================================

simulate_cpu() {
  local duration=${1:-180}  # 3 minutos default
  
  print_header "Simulando ALTA CPU"
  
  echo ""
  print_info "Duração: $duration segundos"
  print_info "Usando: container progrium/stress"
  
  echo ""
  print_warning "Iniciando stress de CPU..."
  docker run --rm -d --name observabilidade-stress-cpu progrium/stress --cpu 4 --timeout "${duration}s" >/dev/null
  
  echo ""
  print_info "Observar em Prometheus: (100 - (avg(rate(node_cpu_seconds_total{mode='idle'}[5m])) * 100))"
  
  echo ""
  print_info "Timeline esperado:"
  echo "  • 0s:   Stress inicia, CPU começa a subir"
  echo "  • ~2min: CPU > 80% por 2min → HighCpuWarning (🟡) em Slack"
  echo "  • ~1min: CPU > 95% por 1min → HighCpuCritical (🔴) em Slack"
  echo "  • ~${duration}s: Stress termina, CPU volta ao normal"
  echo "  • +4h:  Alertas repetem (repeat_interval: 4h)"
  
  echo ""
  print_warning "Aguardando stress terminar (${duration}s)..."
  sleep "$duration"
  
  print_success "Stress finalizado"
  echo ""
  print_info "Verifique alertas resolvidos no Slack e/ou Discord"
}

# ============================================================
# FUNÇÃO: OPÇÃO C - Pressão de Memória
# ============================================================

simulate_memory() {
  print_header "Simulando PRESSÃO DE MEMÓRIA"
  
  echo ""
  print_info "Método: Criar arquivo grande em /tmp"
  print_info "Alvo: Reduzir MemAvailable abaixo de 10%"
  
  local duration=${1:-180}
  local target_mb=${2:-768}
  
  echo ""
  print_warning "Alocando ~${target_mb}MB de memória..."
  
  docker run --rm -d --name observabilidade-stress-mem progrium/stress --vm 1 --vm-bytes "${target_mb}M" --timeout "${duration}s" >/dev/null
  
  echo ""
  print_info "Observar em Prometheus: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
  print_info "Esperado: LowMemoryAvailable (crítico 🔴) no Slack"
  
  echo ""
  print_warning "Aguardando stress de memória terminar (${duration}s)..."
  sleep "$duration"
  
  print_success "Memória liberada"
}

# ============================================================
# FUNÇÃO: OPÇÃO D - Latência Alta
# ============================================================

simulate_latency() {
  local duration=${1:-300}

  print_header "Simulando LATÊNCIA ALTA"
  
  echo ""
  print_warning "Gerando requisicoes com delay de 1.2s..."
  
  echo ""
  print_info "Observar em Prometheus:"
  echo "  P50: histogram_quantile(0.50, ...)"
  echo "  P95: histogram_quantile(0.95, ...)"
  echo "  P99: histogram_quantile(0.99, ...)"
  
  print_info "Esperado: HighLatencyP99 (warning 🟡) no Slack/Discord após 5min"
  
  echo ""
  print_warning "Gerando tráfego lento por ${duration}s..."
  (
    end_time=$((SECONDS + duration))
    while [ $SECONDS -lt $end_time ]; do
      curl -s "http://localhost:8080/delay/1.2" > /dev/null 2>&1 || true
    done
  )
  
  print_success "Latência normalizada"
}

# ============================================================
# FUNÇÃO: OPÇÃO E - Injetar Erros HTTP
# ============================================================

simulate_errors() {
  print_header "Simulando ERROS HTTP 500"
  
  echo ""
  print_info "Gerando requisições com erro via curl em loop..."
  
  # Gerar 100 requisições por segundo com erro
  (
    for i in {1..300}; do
      curl -s "http://localhost:8080/status/500" > /dev/null 2>&1 &
      if [ $((i % 50)) -eq 0 ]; then
        echo -ne "  Requisições com erro: $i/300\r"
      fi
      sleep 0.01
    done
    wait
  ) &
  
  local loop_pid=$!
  
  echo ""
  print_info "Observar em Prometheus: (sum(rate(http_requests_total{status=~'5..'}[5m])) / sum(rate(http_requests_total[5m]))) * 100"
  print_info "Esperado: HighErrorRate (warning 🟡) no Slack/Discord após 5min"
  
  echo ""
  print_info "Aguardando 5 minutos para acumular erros..."
  echo "  • 0min:  Erros começam"
  echo "  • 5min:  HighErrorRate disparado se > 5%"
  echo ""
  
  sleep 300
  kill $loop_pid 2>/dev/null || true
  print_success "Teste de erros finalizado"
}

# ============================================================
# FUNÇÃO: OPÇÃO F - Cenário Combinado
# ============================================================

simulate_combined() {
  print_header "Simulando MÚLTIPLAS FALHAS (Cenário Real)"
  
  echo ""
  print_warning "Iniciando:"
  echo "  1. Alta CPU (stress-ng)"
  echo "  2. Requisições lentas (simulação)"
  echo "  3. Alguns erros HTTP"
  
  # 1. Stress CPU
  print_info "Iniciando stress de CPU..."
  docker run --rm -d --name observabilidade-stress-combined progrium/stress --cpu 4 --timeout 300s >/dev/null
  
  # 2. Gerar requisições lentas
  print_info "Gerando requisições para o app..."
  (
    for i in {1..100}; do
      curl -s "http://localhost:8080/delay/2" > /dev/null 2>&1 &
      sleep 0.1
    done
  ) &
  
  # 3. Alguns erros
  print_info "Injetando alguns erros..."
  (
    for i in {1..50}; do
      curl -s "http://localhost:8080/status/500" > /dev/null 2>&1 &
      sleep 0.2
    done
  ) &
  
  echo ""
  print_info "Cenário rodando por 5 minutos..."
  print_info "Esperado: Agrupamento de múltiplos alertas em 1 mensagem Slack"
  echo ""
  print_info "Alertas esperados:"
  echo "  • HighCpuWarning ou HighCpuCritical"
  echo "  • HighLatencyP99"
  echo "  • HighErrorRate"
  echo ""
  
  sleep 300
  
  print_info "Finalizando teste combinado..."
  docker rm -f observabilidade-stress-combined 2>/dev/null || true
  
  print_success "Cenário combinado finalizado"
}

# ============================================================
# FUNÇÃO: Cleanup
# ============================================================

cleanup() {
  print_header "Limpando containers e processos de teste"
  
  echo ""
  print_warning "Matando processos de stress..."
  docker rm -f observabilidade-stress-cpu observabilidade-stress-mem observabilidade-stress-combined 2>/dev/null || true
  pkill -f "curl.*5" 2>/dev/null || true
  
  echo ""
  print_warning "Removendo arquivos temporários..."
  rm -f /tmp/memtest.bin /tmp/*.stress
  
  echo ""
  print_warning "Restaurando containers..."
  docker compose up -d app 2>/dev/null || true
  
  print_success "Limpeza finalizada"
}

# ============================================================
# MAIN - Processar argumentos
# ============================================================

main() {
  if [ $# -eq 0 ]; then
    show_help
    exit 0
  fi
  
  case "$1" in
    crash)
      simulate_crash
      ;;
    cpu)
      simulate_cpu "${2:-180}"
      ;;
    memory)
      simulate_memory
      ;;
    latency)
      simulate_latency
      ;;
    errors)
      simulate_errors
      ;;
    combined)
      simulate_combined
      ;;
    list)
      list_status
      ;;
    cleanup)
      cleanup
      ;;
    -h|--help|help)
      show_help
      ;;
    *)
      print_error "Opção desconhecida: $1"
      echo ""
      show_help
      exit 1
      ;;
  esac
}

# ============================================================
# EXECUTAR
# ============================================================

main "$@"
