# Observabilidade Low Cost no EKS

Arquitetura aplicada para reduzir custo:

- Prometheus OSS e Grafana OSS rodam dentro do cluster EKS existente `week5-ci-cd-prod-eks`.
- Prometheus usa um único PVC `gp3` pequeno de `5Gi`.
- Retenção do Prometheus limitada a `24h` e `1GB`.
- Grafana usa `emptyDir`, sem EBS dedicado.
- Serviços são `ClusterIP`; acesso via `kubectl port-forward`, sem LoadBalancer/ALB novo.
- Coleta restrita ao essencial: Prometheus, API server e métricas básicas de CPU, memória, rede e filesystem dos pods dos namespaces `apps` e `observability`.

## Aplicar

```bash
kubectl apply -f k8s/observability-lowcost.yaml
kubectl -n observability get pods,pvc,svc
```

## Acessar

Prometheus:

```bash
kubectl -n observability port-forward svc/prometheus 9090:9090
```

Grafana:

```bash
kubectl -n observability port-forward svc/grafana 3000:3000
```

Credenciais locais do Grafana:

```text
admin / admin
```

## Desligar EC2 antiga

Depois de validar o EKS, a EC2 antiga `i-0c683b9e5744088dd` pode ficar parada para reduzir custo de compute:

```bash
aws ec2 stop-instances --region us-east-1 --instance-ids i-0c683b9e5744088dd
```

Isso preserva o volume EBS da EC2. Para custo ainda menor, revisar snapshots/volumes não usados antes de excluir qualquer recurso.
