#!/usr/bin/env bash
# Sprint 10 - resolution interne/externe, temps de resolution, bascule chronometree (--bascule)
source "$(dirname "$0")/lib.sh"; ENV=prod
APP=$(iid "app-01-prod-AA")
DOMAIN=$(jq -r .edge.PublicDomain "$ROOT/parameters/prod.json")
ZONE=$(out stack-leman-shared-edge-global PublicZoneId us-east-1)
NS=$(aws route53 get-hosted-zone --id "$ZONE" --query 'DelegationSet.NameServers[0]' --output text)
{
echo "== Sprint 10 - $(date -Is)"
echo "-- Interne (depuis app-01, resolveur VPC)"
ssm_run "$APP" "dig +noall +answer +stats web.prod.leman.internal | grep -E 'IN|Query time'" || true
echo "-- Externe (domaine fictif non delegue : interrogation directe de $NS)"
dig +noall +answer +stats "origin.$DOMAIN" @"$NS" | grep -E 'IN|Query time'
dig +noall +answer "portefeuilles.$DOMAIN" @"$NS"
echo "-- DNSSEC"
dig +dnssec +noall +answer DNSKEY "$DOMAIN" @"$NS" | head -3
echo "-- Aucun enregistrement public vers une IP privee"
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE" \
  --query 'ResourceRecordSets[].ResourceRecords[].Value' --output text | tr '\t' '\n' \
  | grep -E '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' && ko "IP privee trouvee" || ok "aucune IP privee publiee"
if [[ "${1:-}" == "--bascule" ]]; then
  echo "-- Bascule : arret de nginx sur web-01 et web-02"
  for w in web-01-prod-AA web-02-prod-AA; do ssm_run "$(iid $w)" "systemctl stop nginx" >/dev/null || true; done
  t0=$(date +%s)
  until dig +short "origin.$DOMAIN" @"$NS" | grep -q 192.0.2.10; do sleep 5; (( $(date +%s)-t0 > 600 )) && break; done
  echo "Bascule vers l'enregistrement de secours en $(( $(date +%s)-t0 )) s"
  for w in web-01-prod-AA web-02-prod-AA; do ssm_run "$(iid $w)" "systemctl start nginx" >/dev/null || true; done
fi
} | proof s10
