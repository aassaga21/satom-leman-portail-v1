#!/usr/bin/env bash
# Associe les attachements VPN et Direct Connect a la table TGW "hybride"
# et les propage dans la table prod (le site client ne voit que prod).
# Idempotent : peut etre relance sans effet de bord.
set -euo pipefail
REGION="${REGION:-eu-north-1}"
out() { aws cloudformation describe-stacks --stack-name "$1" --region "$REGION" \
          --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" --output text; }

TGW=$(out stack-leman-shared-interconnect TgwId)
RT_PROD=$(out stack-leman-shared-interconnect TgwRtProdId)
RT_HYB=$(out stack-leman-shared-hybrid TgwRtHybridId)

ATTS=$(aws ec2 describe-transit-gateway-attachments --region "$REGION" \
  --filters Name=transit-gateway-id,Values="$TGW" Name=resource-type,Values=vpn,direct-connect-gateway \
            Name=state,Values=available,pending \
  --query 'TransitGatewayAttachments[].TransitGatewayAttachmentId' --output text)

for att in $ATTS; do
  current=$(aws ec2 describe-transit-gateway-attachments --region "$REGION" \
    --transit-gateway-attachment-ids "$att" \
    --query 'TransitGatewayAttachments[0].Association.TransitGatewayRouteTableId' --output text)
  if [[ "$current" != "$RT_HYB" ]]; then
    echo "Association $att -> $RT_HYB"
    aws ec2 associate-transit-gateway-route-table --region "$REGION" \
      --transit-gateway-route-table-id "$RT_HYB" --transit-gateway-attachment-id "$att" >/dev/null
  fi
  if ! aws ec2 get-transit-gateway-route-table-propagations --region "$REGION" \
        --transit-gateway-route-table-id "$RT_PROD" \
        --query "TransitGatewayRouteTablePropagations[?TransitGatewayAttachmentId=='$att']" \
        --output text | grep -q "$att"; then
    echo "Propagation $att -> $RT_PROD"
    aws ec2 enable-transit-gateway-route-table-propagation --region "$REGION" \
      --transit-gateway-route-table-id "$RT_PROD" --transit-gateway-attachment-id "$att" >/dev/null
  fi
done
echo "Routage hybride TGW a jour."
