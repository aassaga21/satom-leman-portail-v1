#!/usr/bin/env bash
# Sprints 5 et 6 - depuis dev-01 (10.1.1.10) : app-01 prod sur 8080 OK, web-01 sur 22 bloque,
# traceroute TCP et chemin Reachability Analyzer (montre pcx- ou tgw-)
source "$(dirname "$0")/lib.sh"
DEV=$(iid "dev-01-AA"); APPIP=$(ip_of "app-01-prod-AA"); WEBIP=$(ip_of "web-01-prod-AA")
MODE=$(jq -r .interconnect.Mode "$ROOT/parameters/shared.json")
{
echo "== Sprints 5/6 (mode $MODE) - $(date -Is)"
echo "-- dev-01 -> app-01 ($APPIP) tcp/8080"
ssm_run "$DEV" "nc -zv -w 5 $APPIP 8080 2>&1" && ok "8080 joignable" || ko "8080 injoignable"
echo "-- dev-01 -> web-01 ($WEBIP) tcp/22"
ssm_run "$DEV" "nc -zv -w 5 $WEBIP 22 2>&1" && ko "22 joignable (NON conforme)" || ok "22 bloque"
echo "-- traceroute TCP vers app-01"
ssm_run "$DEV" "traceroute -n -T -p 8080 -w 2 -m 6 $APPIP" || true
echo "-- Composants du chemin (Reachability Analyzer)"
P=$(aws ec2 create-network-insights-path --region "$REGION" --source "$DEV" --destination "$(iid app-01-prod-AA)" \
     --protocol tcp --destination-port 8080 --query NetworkInsightsPath.NetworkInsightsPathId --output text)
A=$(aws ec2 start-network-insights-analysis --region "$REGION" --network-insights-path-id "$P" \
     --query NetworkInsightsAnalysis.NetworkInsightsAnalysisId --output text)
sleep 60
aws ec2 describe-network-insights-analyses --region "$REGION" --network-insights-analysis-ids "$A" \
  --query 'NetworkInsightsAnalyses[0].ForwardPathComponents[].Component.Id' --output text | tr '\t' '\n'
} | proof s05-s06
! grep -q "\[KO\]" "$PREUVES/s05-s06-$STAMP.txt"
