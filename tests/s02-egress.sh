#!/usr/bin/env bash
# Sprint 2 - sortie depuis app-01 vers un depot de paquets ; acces entrant refuse
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
APP=$(iid "app-01-$ENV-AA")
{
echo "== Sprint 2 ($ENV) - $(date -Is)"
echo "-- app-01 : dnf makecache (sortie via NAT)"
ssm_run "$APP" "dnf -q makecache && echo DEPOT_OK; curl -s -o /dev/null -w 'IP publique de sortie (NAT) : %{remote_ip}\n' https://checkip.amazonaws.com" || true
echo "-- app-01 : adresse IP publique ?"
aws ec2 describe-instances --region "$REGION" --instance-ids "$APP" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
echo "-- ALB en direct depuis Internet (doit echouer : sg-alb limite a CloudFront)"
ALB=$(out "stack-leman-$ENV-edge" AlbDnsName 2>/dev/null || echo "")
[[ -n "$ALB" ]] && (curl -s -m 8 -o /dev/null -w '%{http_code}\n' "http://$ALB/" || echo "connexion refusee/expiree : OK")
} | proof s02
