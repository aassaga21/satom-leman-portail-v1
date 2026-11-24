#!/usr/bin/env bash
# Suppression dans l'ordre inverse des dependances (exports/imports).
#   scripts/destroy.sh dev | prod | shared-post | shared-pre
# Pour la demo : destroy.sh shared-post puis destroy.sh dev, puis deploy.sh dev, puis deploy.sh shared-post
set -euo pipefail
TARGET="${1:?usage: destroy.sh <dev|prod|shared-post|shared-pre>}"
REGION="${REGION:-eu-central-2}"

del() { # nom region
  local st
  st=$(aws cloudformation describe-stacks --stack-name "$1" --region "$2" \
        --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo ABSENTE)
  [[ "$st" == ABSENTE ]] && { echo "$1 deja absente"; return 0; }
  echo "==> Suppression $1 ($2)"
  aws cloudformation delete-stack --stack-name "$1" --region "$2"
  aws cloudformation wait stack-delete-complete --stack-name "$1" --region "$2"
}

empty_bucket() { # stack cle_output
  local b
  b=$(aws cloudformation describe-stacks --stack-name "$1" --region "$REGION" \
      --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" --output text 2>/dev/null || true)
  [[ -z "$b" || "$b" == None ]] && return 0
  echo "Vidage de s3://$b (toutes versions)"
  python3 - "$b" "$REGION" <<'PY'
import sys, boto3
b = boto3.resource("s3", region_name=sys.argv[2]).Bucket(sys.argv[1])
b.object_versions.delete()
PY
}

case "$TARGET" in
  dev|prod)
    empty_bucket "stack-leman-$TARGET-edge" StaticBucketName
    # Le bucket de journaux ALB n'est pas en sortie : on le vide via la ressource physique
    lb=$(aws cloudformation describe-stack-resource --stack-name "stack-leman-$TARGET-edge" --region "$REGION" \
          --logical-resource-id LogsBucket --query StackResourceDetail.PhysicalResourceId --output text 2>/dev/null || true)
    if [[ -n "$lb" && "$lb" != None ]]; then
      python3 -c "import boto3,sys; boto3.resource('s3',region_name='$REGION').Bucket('$lb').object_versions.delete()"
    fi
    for s in monitoring edge compute security network base; do del "stack-leman-$TARGET-$s" "$REGION"; done ;;
  shared-post)
    del stack-leman-shared-hybrid "$REGION"
    del stack-leman-shared-interconnect "$REGION" ;;
  shared-pre)
    del stack-leman-shared-account "$REGION"
    del stack-leman-shared-edge-global us-east-1
    del stack-leman-shared-budget us-east-1 ;;
  *) echo "cible inconnue" >&2; exit 1 ;;
esac
echo "Suppression terminee : $TARGET"
