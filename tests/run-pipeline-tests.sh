#!/usr/bin/env bash
# Tests executes par la pipeline (etape 4) : connectivite, sante des cibles, temps de reponse.
# Chaque test n'est lance que si les stacks dont il depend existent (livraison sprint par sprint).
set -uo pipefail
D="$(dirname "$0")"; ENV="${1:-dev}"; rc=0
source "$D/lib.sh"; set +e
has() { aws cloudformation describe-stacks --stack-name "stack-leman-$ENV-$1" --region "$REGION" >/dev/null 2>&1; }

has network && { "$D/s01-subnets.sh" "$ENV" || rc=1; }
has compute && [[ "$ENV" == prod ]] && { "$D/s03-reachability.sh" "$ENV" || rc=1; }   # Reachability Analyzer facture (~0,10 USD/analyse) : prod uniquement
if has edge; then
  "$D/s09-alb.sh" "$ENV" || rc=1
  "$D/perf-p95.sh" "$ENV" 50 || rc=1
  for k in TgWebArn TgAppArn; do
    for _ in $(seq 1 12); do   # jusqu'a 2 min pour que les nouvelles cibles deviennent saines
      bad=$(aws elbv2 describe-target-health --region "$REGION" --target-group-arn "$(out "stack-leman-$ENV-edge" $k)" \
            --query "TargetHealthDescriptions[?TargetHealth.State!='healthy'] | length(@)")
      [[ "$bad" == 0 ]] && break; sleep 10
    done
    [[ "$bad" == 0 ]] && ok "$k : toutes les cibles saines" || { ko "$k : $bad cible(s) non saine(s)"; rc=1; }
  done
fi
exit $rc
