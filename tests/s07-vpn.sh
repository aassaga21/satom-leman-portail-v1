#!/usr/bin/env bash
# Sprint 7 - etat des tunnels et metrique TunnelState
source "$(dirname "$0")/lib.sh"
{
echo "== Sprint 7 - $(date -Is)"
for k in Vpn1Id Vpn2Id; do
  V=$(out stack-leman-shared-hybrid "$k")
  echo "-- $V"
  aws ec2 describe-vpn-connections --region "$REGION" --vpn-connection-ids "$V" \
    --query 'VpnConnections[0].VgwTelemetry[].[OutsideIpAddress,Status,StatusMessage,AcceptedRouteCount]' --output table
  aws cloudwatch get-metric-statistics --region "$REGION" --namespace AWS/VPN --metric-name TunnelState \
    --dimensions Name=VpnId,Value="$V" --statistics Average --period 300 \
    --start-time "$(date -u -d '-30 min' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
    --query 'sort_by(Datapoints,&Timestamp)[].[Timestamp,Average]' --output table
done
echo "-- Pre-cles : stockage Secrets Manager (aucune dans le depot)"
aws secretsmanager list-secrets --region "$REGION" --filters Key=name,Values=vpn --query 'SecretList[].Name' --output text || true
} | proof s07
