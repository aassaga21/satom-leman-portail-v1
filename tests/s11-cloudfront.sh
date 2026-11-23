#!/usr/bin/env bash
# Sprint 11 - en-tete x-cache, taux de cache local et metrique CacheHitRate
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
CF=$(out "stack-leman-$ENV-edge" DistributionDomain); DID=$(out "stack-leman-$ENV-edge" DistributionId)
{
echo "== Sprint 11 ($ENV) - $(date -Is) - https://$CF"
for i in 1 2; do curl -sI "https://$CF/static/style.css" | grep -iE '^(x-cache|age):'; done
hits=0; n=100
for i in $(seq 1 $n); do
  f=$([[ $((i%2)) == 0 ]] && echo style.css || echo test-cache-20k.txt)
  curl -sI "https://$CF/static/$f" | grep -qi 'x-cache: Hit' && hits=$((hits+1))
done
echo "Taux de Hit observe sur $n requetes statiques : $hits %"
echo "-- /api/* non mis en cache"
curl -sI "https://$CF/api/health" | grep -iE '^(x-cache|HTTP)'
echo "-- WAF : limitation de debit -> voir tests/load-test.js ; ALB direct refuse -> s02"
echo "-- CacheHitRate (CloudWatch us-east-1, peut demander 5-10 min)"
aws cloudwatch get-metric-statistics --region us-east-1 --namespace AWS/CloudFront --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value="$DID" Name=Region,Value=Global --statistics Average --period 300 \
  --start-time "$(date -u -d '-1 hour' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
  --query 'sort_by(Datapoints,&Timestamp)[].[Timestamp,Average]' --output table
} | proof s11
