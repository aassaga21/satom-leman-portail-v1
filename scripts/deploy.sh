#!/usr/bin/env bash
# =====================================================================
# Deploiement par change sets - SatomCloudNetwork
#   scripts/deploy.sh shared-pre          budget + edge-global (us-east-1), account
#   scripts/deploy.sh dev|prod [stack..]  base network security compute edge monitoring
#   scripts/deploy.sh shared-post         interconnect (+ hybrid si Mode=tgw)
# Variables : CFN_ROLE_ARN (role d'execution CloudFormation, recommande)
#             REGION (defaut eu-north-1)
# Prerequis : aws cli v2, jq
# =====================================================================
set -euo pipefail

TARGET="${1:?usage: deploy.sh <shared-pre|dev|prod|shared-post> [stack...]}"
shift || true
REGION="${REGION:-eu-north-1}"
GLOBAL_REGION="us-east-1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$ROOT/templates"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

stack_status() { # nom region
  aws cloudformation describe-stacks --stack-name "$1" --region "$2" \
    --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "ABSENTE"
}

stack_output() { # nom region cle
  aws cloudformation describe-stacks --stack-name "$1" --region "$2" \
    --query "Stacks[0].Outputs[?OutputKey=='$3'].OutputValue" --output text 2>/dev/null || true
}

# Construit la liste de parametres CloudFormation (JSON) :
# section "common" + section du stack + surcharges calculees "CLE=VALEUR"
build_params() { # fichier section [CLE=VALEUR...]
  local file="$1" section="$2"; shift 2
  local extra='{}'
  for kv in "$@"; do
    extra=$(jq -c --arg k "${kv%%=*}" --arg v "${kv#*=}" '. + {($k): $v}' <<<"$extra")
  done
  jq -c --arg s "$section" --argjson x "$extra" '
    ((.common // {}) + (.[$s] // {}) + $x)
    | to_entries | map({ParameterKey: .key, ParameterValue: (.value|tostring)})' "$file"
}

deploy_stack() { # nom template region params_json
  local name="$1" template="$2" region="$3" params="$4" env_tag="$5"
  local status type cs
  if [[ ! -f "$template" ]]; then
    echo "Template $(basename "$template") absent du depot : $name ignoree (sprint pas encore livre)"
    return 0
  fi
  status=$(stack_status "$name" "$region")
  if [[ "$status" == "ROLLBACK_COMPLETE" || "$status" == "REVIEW_IN_PROGRESS" ]]; then
    log "$name en $status : suppression avant recreation"
    aws cloudformation delete-stack --stack-name "$name" --region "$region"
    aws cloudformation wait stack-delete-complete --stack-name "$name" --region "$region"
    status="ABSENTE"
  fi
  [[ "$status" == "ABSENTE" ]] && type=CREATE || type=UPDATE
  cs="cs-$(date +%Y%m%d%H%M%S)"

  log "$name ($region) : change set $type $cs"
  local role_args=()
  [[ -n "${CFN_ROLE_ARN:-}" ]] && role_args=(--role-arn "$CFN_ROLE_ARN")

  aws cloudformation create-change-set \
    --stack-name "$name" --region "$region" \
    --change-set-name "$cs" --change-set-type "$type" \
    --template-body "file://$template" \
    --parameters "$params" \
    --capabilities CAPABILITY_NAMED_IAM \
    --tags Key=Projet,Value=SatomCloudNetwork Key=Equipe,Value=Assaga "Key=Environnement,Value=$env_tag" \
    "${role_args[@]}" >/dev/null

  if ! aws cloudformation wait change-set-create-complete \
        --stack-name "$name" --change-set-name "$cs" --region "$region" 2>/dev/null; then
    local reason
    reason=$(aws cloudformation describe-change-set --stack-name "$name" --change-set-name "$cs" \
              --region "$region" --query StatusReason --output text)
    if [[ "$reason" == *"didn't contain changes"* || "$reason" == *"No updates"* ]]; then
      echo "Aucun changement pour $name"
      aws cloudformation delete-change-set --stack-name "$name" --change-set-name "$cs" --region "$region"
      return 0
    fi
    echo "Echec du change set : $reason" >&2
    exit 1
  fi

  aws cloudformation describe-change-set --stack-name "$name" --change-set-name "$cs" --region "$region" \
    --query 'Changes[].ResourceChange.[Action,LogicalResourceId,ResourceType,Replacement]' --output table

  aws cloudformation execute-change-set --stack-name "$name" --change-set-name "$cs" --region "$region"
  if [[ "$type" == CREATE ]]; then
    aws cloudformation wait stack-create-complete --stack-name "$name" --region "$region"
  else
    aws cloudformation wait stack-update-complete --stack-name "$name" --region "$region"
  fi
  echo "OK : $name -> $(stack_status "$name" "$region")"
}

cloudfront_prefix_list() {
  aws ec2 describe-managed-prefix-lists --region "$REGION" \
    --filters Name=prefix-list-name,Values=com.amazonaws.global.cloudfront.origin-facing \
    --query 'PrefixLists[0].PrefixListId' --output text
}

deploy_env() { # env [stacks...]
  local env="$1"; shift
  local file="$ROOT/parameters/$env.json"
  local stacks=("$@")
  [[ ${#stacks[@]} -eq 0 ]] && stacks=(base network security compute edge monitoring)

  for s in "${stacks[@]}"; do
    local name="stack-leman-$env-$s" extra=()
    case "$s" in
      base)       tpl=01-base.yaml ;;
      network)    tpl=02-network.yaml ;;
      security)   tpl=03-security.yaml; extra=("CloudFrontPrefixListId=$(cloudfront_prefix_list)") ;;
      compute)    tpl=04-compute.yaml ;;
      edge)       tpl=08-edge.yaml
                  extra=("WebAclArn=$(stack_output stack-leman-shared-edge-global $GLOBAL_REGION WebAclArn)")
                  [[ "$env" == prod ]] && extra+=("PublicHostedZoneId=$(stack_output stack-leman-shared-edge-global $GLOBAL_REGION PublicZoneId)") ;;
      monitoring) tpl=09-monitoring.yaml
                  extra=("CloudFrontDistributionId=$(stack_output stack-leman-$env-edge "$REGION" DistributionId)")
                  if [[ "$env" == prod ]]; then
                    extra+=("Vpn1Id=$(stack_output stack-leman-shared-hybrid "$REGION" Vpn1Id)")
                    extra+=("Vpn2Id=$(stack_output stack-leman-shared-hybrid "$REGION" Vpn2Id)")
                  fi ;;
      *) echo "stack inconnue : $s" >&2; exit 1 ;;
    esac
    [[ -f "$TPL/$tpl" ]] || { echo "$tpl absent : $name ignoree"; continue; }
    deploy_stack "$name" "$TPL/$tpl" "$REGION" "$(build_params "$file" "$s" "${extra[@]}")" "$env"

    if [[ "$s" == edge ]]; then
      local bucket
      bucket=$(stack_output "$name" "$REGION" StaticBucketName)
      log "Publication du contenu statique vers s3://$bucket/static/"
      aws s3 sync "$ROOT/site/static/" "s3://$bucket/static/" --delete --region "$REGION"
    fi
  done
}

case "$TARGET" in
  shared-pre)
    F="$ROOT/parameters/shared.json"
    deploy_stack stack-leman-shared-budget      "$TPL/00-budget.yaml"      "$GLOBAL_REGION" "$(build_params "$F" budget)" prod
    deploy_stack stack-leman-shared-edge-global "$TPL/07-edge-global.yaml" "$GLOBAL_REGION" "$(build_params "$F" edge-global)" prod
    deploy_stack stack-leman-shared-account     "$TPL/00-account.yaml"     "$REGION"        "$(build_params "$F" account)" prod
    ;;
  dev|prod)
    deploy_env "$TARGET" "$@"
    ;;
  shared-post)
    F="$ROOT/parameters/shared.json"
    deploy_stack stack-leman-shared-interconnect "$TPL/05-interconnect.yaml" "$REGION" "$(build_params "$F" interconnect)" prod
    if [[ "$(jq -r '.interconnect.Mode' "$F")" == "tgw" ]]; then
      deploy_stack stack-leman-shared-hybrid "$TPL/06-hybrid.yaml" "$REGION" "$(build_params "$F" hybrid)" prod
      "$ROOT/scripts/tgw-hybrid-routing.sh"
    fi
    ;;
  *) echo "cible inconnue : $TARGET" >&2; exit 1 ;;
esac
log "Termine : $TARGET"
