#!/usr/bin/env bash
# Sprint 12 - alarme 5xx de bout en bout : erreurs provoquees -> ALARM -> e-mail SNS
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
CF=$(out "stack-leman-$ENV-edge" DistributionDomain); ALARM="leman-$ENV-alb-5xx-cibles"
{
echo "== Sprint 12 ($ENV) - $(date -Is)"
t0=$(date +%s)
for i in $(seq 1 30); do curl -s -o /dev/null "https://$CF/api/error"; done
echo "30 erreurs 500 provoquees a $(date -Is)"
until [[ $(aws cloudwatch describe-alarms --region "$REGION" --alarm-names "$ALARM" --query 'MetricAlarms[0].StateValue' --output text) == ALARM ]]; do
  sleep 10; (( $(date +%s)-t0 > 600 )) && { ko "alarme non declenchee en 10 min"; break; }
done
echo "Alarme $ALARM en ALARM apres $(( $(date +%s)-t0 )) s (seuil : < 300 s)"
aws cloudwatch describe-alarm-history --region "$REGION" --alarm-name "$ALARM" --history-item-type StateUpdate \
  --max-items 3 --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' --output table
echo "=> Faire une capture de l'e-mail SNS recu (heure de reception)."
} | proof s12
