#!/usr/bin/env bash
# Sprint 9 - sante des cibles, puis panne simulee de web-01 : delai de bascule et taux d'erreur client
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
URL="https://$(out "stack-leman-$ENV-edge" DistributionDomain)/"
TGW=$(out "stack-leman-$ENV-edge" TgWebArn); TGA=$(out "stack-leman-$ENV-edge" TgAppArn)
WEB1=$(iid "web-01-$ENV-AA")
health() { aws elbv2 describe-target-health --region "$REGION" --target-group-arn "$1" \
             --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output text; }
{
echo "== Sprint 9 ($ENV) - $(date -Is)"
echo "-- tg-web"; health "$TGW"; echo "-- tg-app"; health "$TGA"
[[ "${2:-}" == "--panne" ]] || exit 0
echo "-- Panne simulee : arret de nginx sur web-01 ($WEB1)"
ssm_run "$WEB1" "systemctl stop nginx" >/dev/null || true
t0=$(date +%s); total=0; err=0; detect=""
while (( $(date +%s) - t0 < 90 )); do
  code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$URL" || echo 000)
  total=$((total+1)); [[ "$code" =~ ^(5..|000)$ ]] && err=$((err+1))
  if [[ -z "$detect" ]] && health "$TGW" | grep -q "$WEB1.*unhealthy"; then detect=$(( $(date +%s) - t0 )); fi
  sleep 1
done
echo "Delai de detection (cible unhealthy) : ${detect:-non detecte} s"
echo "Requetes : $total ; erreurs 5xx/timeout : $err ; taux d'erreur : $(awk "BEGIN{printf \"%.2f\", 100*$err/$total}") %"
ssm_run "$WEB1" "systemctl start nginx" >/dev/null || true
echo "nginx redemarre sur web-01"
} | proof s09
