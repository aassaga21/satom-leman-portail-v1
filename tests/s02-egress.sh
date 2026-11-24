#!/usr/bin/env bash
# Sprint 2 - sortie depuis app-01 vers un depot de paquets via la NAT ; aucune IP publique
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
APP=$(iid "app-01-$ENV-AA")
# checkip.amazonaws.com renvoie dans sa reponse l'IP publique vue depuis Internet
# (%{remote_ip} de curl donnait l'IP du serveur contacte, pas l'IP de sortie).
OUTP=$(ssm_run "$APP" "dnf -q makecache && echo DEPOT_OK; curl -s https://checkip.amazonaws.com" || true)
OUTP=$(tr -d '\r' <<<"$OUTP")
EGRESS=$(grep -Eo '^[0-9]+(\.[0-9]+){3}$' <<<"$OUTP" | tail -1 || true)
NATIP=$(aws ec2 describe-nat-gateways --region "$REGION" \
          --filter "Name=tag:Name,Values=nat-$ENV-leman-AA" Name=state,Values=available \
          --query 'NatGateways[0].NatGatewayAddresses[0].PublicIp' --output text)
PUB=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$APP" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
ALB=$(out "stack-leman-$ENV-edge" AlbDnsName 2>/dev/null || echo "")
{
echo "== Sprint 2 ($ENV) - $(date -Is)"
echo "-- app-01 : dnf makecache puis IP de sortie"
echo "$OUTP"
echo "-- IP de sortie d'app-01 : ${EGRESS:-inconnue}"
echo "-- IP publique de la NAT : $NATIP"
grep -q DEPOT_OK <<<"$OUTP" && ok "depot de paquets joignable depuis app-01" || ko "depot de paquets injoignable"
[[ -n "$EGRESS" && "$EGRESS" == "$NATIP" ]] && ok "sortie via la NAT ($NATIP)" || ko "IP de sortie differente de l'IP de la NAT"
echo "-- app-01 : adresse IP publique : $PUB"
[[ "$PUB" == None ]] && ok "app-01 sans IP publique" || ko "app-01 possede une IP publique"
echo "-- ALB en direct depuis Internet (doit echouer : sg-alb limite a CloudFront)"
if [[ -n "$ALB" && "$ALB" != None ]]; then
  curl -s -m 8 -o /dev/null -w '%{http_code}\n' "http://$ALB/" || echo "connexion refusee/expiree : OK"
else
  echo "ALB pas encore deploye (sprint 9)"
fi
} | proof s02
! grep -q "\[KO\]" "$PREUVES/s02-$STAMP.txt"
