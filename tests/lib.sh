#!/usr/bin/env bash
# Fonctions communes aux tests. Chaque test ecrit sa preuve dans docs/preuves/.
set -euo pipefail
REGION="${REGION:-eu-central-2}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREUVES="$ROOT/docs/preuves"; mkdir -p "$PREUVES"
STAMP="$(date +%Y%m%d-%H%M%S)"

out() { # stack cle [region]
  aws cloudformation describe-stacks --stack-name "$1" --region "${3:-$REGION}" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" --output text
}
iid() { # nom (tag Name)
  aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=$1" Name=instance-state-name,Values=running \
    --query 'Reservations[0].Instances[0].InstanceId' --output text
}
ip_of() { # nom
  aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=$1" Name=instance-state-name,Values=running \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text
}
ssm_run() { # instance_id "commande" -> stdout distant ; code retour distant
  local id="$1" cmd="$2" cid st
  cid=$(aws ssm send-command --region "$REGION" --instance-ids "$id" \
        --document-name AWS-RunShellScript \
        --parameters "$(jq -cn --arg c "$cmd" '{commands:[$c]}')" \
        --query Command.CommandId --output text)
  for _ in $(seq 1 30); do
    sleep 2
    st=$(aws ssm get-command-invocation --region "$REGION" --command-id "$cid" --instance-id "$id" \
          --query Status --output text 2>/dev/null || echo Pending)
    [[ "$st" =~ ^(Success|Failed|TimedOut|Cancelled)$ ]] && break
  done
  aws ssm get-command-invocation --region "$REGION" --command-id "$cid" --instance-id "$id" \
    --query StandardOutputContent --output text
  [[ "$st" == Success ]]
}
ok()  { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
ko()  { printf '\033[31m[KO]\033[0m %s\n' "$*"; FAILS=$((FAILS+1)); }
FAILS=0
proof() { tee -a "$PREUVES/$1-$STAMP.txt"; }  # usage : commande | proof s01
