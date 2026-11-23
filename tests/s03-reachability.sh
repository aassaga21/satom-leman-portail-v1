#!/usr/bin/env bash
# Sprint 3 - VPC Reachability Analyzer : web-01 -> app-01 sur 8080 (joignable) et 22 (bloque)
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
SRC=$(iid "web-01-$ENV-AA"); DST=$(iid "app-01-$ENV-AA")
analyse() { # port attendu(true/false)
  local path aid res
  path=$(aws ec2 create-network-insights-path --region "$REGION" --source "$SRC" --destination "$DST" \
          --protocol tcp --destination-port "$1" \
          --tag-specifications "ResourceType=network-insights-path,Tags=[{Key=Projet,Value=SatomCloudNetwork},{Key=Equipe,Value=Assaga},{Key=Environnement,Value=$ENV}]" \
          --query NetworkInsightsPath.NetworkInsightsPathId --output text)
  aid=$(aws ec2 start-network-insights-analysis --region "$REGION" --network-insights-path-id "$path" \
          --query NetworkInsightsAnalysis.NetworkInsightsAnalysisId --output text)
  for _ in $(seq 1 40); do
    sleep 5
    res=$(aws ec2 describe-network-insights-analyses --region "$REGION" --network-insights-analysis-ids "$aid" \
          --query 'NetworkInsightsAnalyses[0].[Status,NetworkPathFound]' --output text)
    [[ "$res" == succeeded* ]] && break
  done
  echo "web-01 -> app-01 tcp/$1 : $res (analyse $aid)"
  if [[ "$res" == *"$2"* ]]; then ok "tcp/$1 conforme ($2)"; else ko "tcp/$1 non conforme"; fi
  [[ "$2" == False ]] && aws ec2 describe-network-insights-analyses --region "$REGION" --network-insights-analysis-ids "$aid" \
     --query 'NetworkInsightsAnalyses[0].Explanations[0].[ExplanationCode,SecurityGroup.Id]' --output text
}
{ echo "== Sprint 3 ($ENV) - $(date -Is)"; analyse 8080 True; analyse 22 False; } | proof s03
! grep -q "\[KO\]" "$PREUVES/s03-$STAMP.txt"
