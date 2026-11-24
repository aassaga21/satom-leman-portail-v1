#!/usr/bin/env bash
# Sprint 1 - plages et zones des sous-reseaux + aucun sous-reseau prive vers l'IGW
# La table privee n'existe qu'a partir du sprint 2 : avant, les sous-reseaux prives
# utilisent la table principale du VPC, qui est alors celle controlee.
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
VPC=$(out "stack-leman-$ENV-network" VpcId)

# Table de routage reellement utilisee par un sous-reseau (association explicite, sinon table principale)
rt_of_subnet() {
  local rt
  rt=$(aws ec2 describe-route-tables --region "$REGION" --filters Name=association.subnet-id,Values="$1" \
        --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null)
  if [[ -z "$rt" || "$rt" == None ]]; then
    rt=$(aws ec2 describe-route-tables --region "$REGION" --filters Name=vpc-id,Values="$VPC" Name=association.main,Values=true \
          --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null)
  fi
  echo "$rt"
}

PRIV_SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC" Name=tag:Tier,Values=private \
                --query 'Subnets[].SubnetId' --output text)
RT=$(out "stack-leman-$ENV-network" PrivateRouteTableId)
if [[ -z "$RT" || "$RT" == None ]]; then
  RT=$(rt_of_subnet "${PRIV_SUBNETS%%[[:space:]]*}")
  RT_LABEL="table principale $RT (table privee livree au sprint 2)"
else
  RT_LABEL="table privee $RT"
fi

{
echo "== Sprint 1 ($ENV) - $(date -Is)"
aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC" \
  --query 'sort_by(Subnets,&CidrBlock)[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone]' --output table
echo "-- Routes de la $RT_LABEL"
aws ec2 describe-route-tables --region "$REGION" --route-table-ids "$RT" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId,VpcEndpointId,TransitGatewayId,VpcPeeringConnectionId]' --output table
} | proof s01

# Controle de securite : aucune table utilisee par un sous-reseau prive ne route vers l'IGW
igw_total=0
for sn in $PRIV_SUBNETS; do
  rt=$(rt_of_subnet "$sn")
  n=$(aws ec2 describe-route-tables --region "$REGION" --route-table-ids "$rt" \
       --query "RouteTables[0].Routes[?starts_with(GatewayId || '', 'igw-')] | length(@)" --output text)
  igw_total=$(( igw_total + ${n:-0} ))
done
[[ -n "$PRIV_SUBNETS" && "$igw_total" == 0 ]] && ok "aucune route vers l'IGW pour les sous-reseaux prives" \
  || ko "route IGW trouvee pour un sous-reseau prive (ou aucun sous-reseau prive)"
[[ $(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC" Name=tag:Name,Values="sub-public-1b-$ENV-AA" --query 'Subnets[0].CidrBlock' --output text) == 10.?.5.0/24 ]] \
  && ok "sub-public-1b en x.x.5.0/24" || ko "plage sub-public-1b inattendue"
[[ $(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC" Name=tag:Name,Values="sub-fw-1a-$ENV-AA" --query 'Subnets[0].CidrBlock' --output text) == 10.?.4.0/28 ]] \
  && ok "sub-fw-1a en x.x.4.0/28" || ko "plage sub-fw-1a inattendue"
[[ $(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC" Name=mapPublicIpOnLaunch,Values=true --query 'length(Subnets)' --output text) == 0 ]] \
  && ok "MapPublicIpOnLaunch=false sur tous les sous-reseaux" || ko "un sous-reseau attribue une IP publique automatiquement"
exit $FAILS
