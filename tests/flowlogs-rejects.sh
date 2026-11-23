#!/usr/bin/env bash
# Sprint 12 - flux rejetes : requete Logs Insights sur les VPC Flow Logs (derniere heure)
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
LG="/leman/$ENV/vpc-flow-logs"
Q='fields srcAddr, dstAddr, dstPort, protocol | filter action = "REJECT" | stats count(*) as tentatives by srcAddr, dstAddr, dstPort, protocol | sort tentatives desc | limit 15'
QID=$(aws logs start-query --region "$REGION" --log-group-name "$LG" \
      --start-time $(( $(date +%s) - 3600 )) --end-time "$(date +%s)" --query-string "$Q" --output text --query queryId)
sleep 15
{ echo "== Flux rejetes ($ENV) - $(date -Is)"
  aws logs get-query-results --region "$REGION" --query-id "$QID" \
    --query 'results[].[ [?field==`srcAddr`].value|[0], [?field==`dstAddr`].value|[0], [?field==`dstPort`].value|[0], [?field==`tentatives`].value|[0] ]' --output table
  echo "=> Expliquer chaque ligne (scan Internet sur l'ALB, test port 22 du sprint 5, etc.)"; } | proof s12-flowlogs
