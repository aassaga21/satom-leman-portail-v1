#!/usr/bin/env bash
# Sprint 4 - domaine autorise vs domaine bloque, et trace dans le journal ALERT du pare-feu
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
APP=$(iid "app-01-$ENV-AA")
{
echo "== Sprint 4 ($ENV) - $(date -Is)"
echo "-- Domaine autorise (.amazonaws.com)"
ssm_run "$APP" "curl -s -m 8 -o /dev/null -w '%{http_code}\n' https://s3.$REGION.amazonaws.com" || true
echo "-- Domaine NON autorise (www.example.org) : doit echouer"
ssm_run "$APP" "curl -s -m 8 -o /dev/null -w '%{http_code}\n' https://www.example.org || echo BLOQUE" || true
echo "-- Journal ALERT du pare-feu (60 s d'attente pour l'ingestion)"
sleep 60
aws logs filter-log-events --region "$REGION" --log-group-name "/leman/$ENV/network-firewall/alert" \
  --start-time $(( ($(date +%s) - 600) * 1000 )) --filter-pattern '"example.org"' \
  --query 'events[-3:].message' --output text
} | proof s04
