#!/usr/bin/env bash
# lag-drift.sh - simulerer en "nødreparasjon i portalen": fire endringer
# gjort direkte mot Azure, utenom Terraform, som en operatør under press
# kunne gjort for å løse et akutt problem. Terraform vet ingenting om disse.
set -euo pipefail

RG="${1:?Bruk: lag-drift.sh <resource-group>}"

VNET=$(az network vnet list -g "$RG" --query "[0].name" -o tsv)
NSG=$(az network nsg list -g "$RG" --query "[0].name" -o tsv)
SUBNET=$(az network vnet subnet list -g "$RG" --vnet-name "$VNET" --query "[0].name" -o tsv)

echo "VNet:   $VNET"
echo "NSG:    $NSG"
echo "Subnet valgt for frakobling: $SUBNET"
echo

echo "1) Legger til tags på vnet-et (incident-id, modified-by) ..."
az network vnet update -g "$RG" -n "$VNET" \
  --set "tags.incident-id=INC-0042" "tags.modified-by=emergency-response" -o none

echo "2) Kobler NSG fra $SUBNET ..."
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET" \
  --remove networkSecurityGroup -o none

echo "3) Legger til en SSH-regel direkte i NSG-en (utenom Terraform) ..."
az network nsg rule create -g "$RG" --nsg-name "$NSG" -n tillat-ssh-noed \
  --priority 150 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes '*' --source-port-ranges '*' \
  --destination-address-prefixes '*' --destination-port-ranges 22 -o none

echo "4) Lager et ekstra subnett Terraform ikke vet om ..."
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n snet-ekstra-drift \
  --address-prefixes 10.10.9.0/24 -o none

echo
echo "Drift lagt til i $RG."
