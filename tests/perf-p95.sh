#!/usr/bin/env bash
# Performance - p95 cote client (curl) et TargetResponseTime p95 cote ALB (CloudWatch)
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"; N="${2:-200}"
CF=$(out "stack-leman-$ENV-edge" DistributionDomain); ALB=$(out "stack-leman-$ENV-edge" AlbFullName)
{
echo "== Performance ($ENV) - $(date -Is) - $N requetes /api/portefeuilles"
for i in $(seq 1 "$N"); do curl -s -o /dev/null -w '%{time_total}\n' "https://$CF/api/portefeuilles"; done \
  | sort -n | awk '{a[NR]=$1} END{printf "client : p50=%.0f ms  p95=%.0f ms  max=%.0f ms\n", a[int(NR*0.5)]*1000, a[int(NR*0.95)]*1000, a[NR]*1000}'
sleep 120
aws cloudwatch get-metric-statistics --region "$REGION" --namespace AWS/ApplicationELB --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value="$ALB" --extended-statistics p95 --period 300 \
  --start-time "$(date -u -d '-15 min' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
  --query 'sort_by(Datapoints,&Timestamp)[].[Timestamp,ExtendedStatistics.p95]' --output table
echo "Seuil : p95 TargetResponseTime < 0.5 s"
} | proof perf
