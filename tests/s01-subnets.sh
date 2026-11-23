#!/usr/bin/env bash
# Sprint 1 - plages et zones des sous-reseaux + aucun sous-reseau prive vers l'IGW
source "$(dirname "$0")/lib.sh"; ENV="${1:-prod}"
VPC=$(out "stack-leman-$ENV-network" VpcId)
{
echo "== Sprint 1 ($ENV) - $(date -Is)"
aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC" \
  --query 'sort_by(Subnets,&CidrBlock)[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone]' --output table
RT=$(out "stack-leman-$ENV-network" PrivateRouteTableId)
echo "-- Routes de la table privee $RT"
aws ec2 describe-route-tables --region "$REGION" --route-table-ids "$RT" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId,VpcEndpointId,TransitGatewayId,VpcPeeringConnectionId]' --output table
} | proof s01
igw=$(aws ec2 describe-route-tables --region "$REGION" --route-table-ids "$(out "stack-leman-$ENV-network" PrivateRouteTableId)" \
      --query "RouteTables[0].Routes[?starts_with(GatewayId || '', 'igw-')] | length(@)")
[[ "$igw" == 0 ]] && ok "aucune route vers l'IGW dans la table privee" || ko "route IGW trouvee dans la table privee"
[[ $(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC" Name=tag:Name,Values="sub-public-1b-$ENV-AA" --query 'Subnets[0].CidrBlock' --output text) == 10.?.5.0/24 ]] \
  && ok "sub-public-1b en x.x.5.0/24" || ko "plage sub-public-1b inattendue"
exit $FAILS
