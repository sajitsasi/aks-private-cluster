#!/bin/bash

. ./source_vars.sh

MC_AKS_RG=$(az aks show -g ${AZ_RG} --name ${AZ_AKS_NAME} --query nodeResourceGroup -o tsv)
MC_AKS_VNET_NAME=$(az network vnet list -g ${MC_AKS_RG} --query '[*].name' -o tsv)

echo "Adding azure-firewall extension"
az extension add --name azure-firewall

echo "Creating public ip for FW"
az network public-ip create \
  -g ${MC_AKS_RG} \
  -n ${AZ_FW_PUB_IP_NAME} \
  -l ${AZ_LOCATION} \
  --sku "standard" 

echo "Creating Azure Firewall in AKS vnet"
az network firewall create -g ${MC_AKS_RG} -n ${AZ_FW_NAME} -l ${AZ_LOCATION} 
az network firewall ip-config create \
  -g ${MC_AKS_RG} \
  -f ${AZ_FW_NAME} \
  -n ${AZ_FW_IPCONFIG_NAME} \
  --public-ip-address ${AZ_FW_PUB_IP_NAME} \
  --vnet-name ${MC_AKS_VNET_NAME}

AZ_FW_PUB_IP=$(az network public-ip show -g ${MC_AKS_RG} --name ${AZ_FW_PUB_IP_NAME} --query 'ipAddress' -o tsv)
AZ_FW_PVT_IP=$(az network firewall show -g ${MC_AKS_RG} --name ${AZ_FW_NAME} --query 'ipConfigurations[0].privateIpAddress' -o tsv)
echo "Azure FW Public IP: ${AZ_FW_PUB_IP}; Private IP: ${AZ_FW_PVT_IP}"
sleep 5

echo "Adding FQDN rules to Firewall ${AKS_FW_NAME}"
az network firewall application-rule create \
  -g ${MC_AKS_RG} \
  -f ${AZ_FW_NAME} \
  --collection-name 'aksfwar' \
  -n 'fqdn' --source-addresses '*' \
  --protocols 'http=80' 'https=443' \
  --target-fqdns '*.azurecr.io' '*.azmk8s.io' 'aksrepos.azurecr.io' \
  '*blob.core.windows.net' '*mcr.microsoft.com' '*.cdn.mscr.io' \
  'login.microsoftonline.com' 'management.azure.com' '*ubuntu.com' \
  '*.docker.io' '*.quay.io' '*.gcr.io' '*.kubernetes.io' '*debian.org' \
  --action allow \
  --priority 1000

echo "Adding Network rules to Firewall ${AKS_FW_NAME}"
az network firewall network-rule create \
  -g ${MC_AKS_RG} \
  -f ${AZ_FW_NAME} \
  --collection-name 'aksfwnr' \
  -n 'netrules' \
  --protocols 'TCP' \
  --source-addresses '*' \
  --destination-addresses '13.0.0.0/8' '20.0.0.0/8' '23.0.0.0/8' '40.0.0.0/8' \
  '51.0.0.0/8' '52.0.0.0/8' '65.0.0.0/8' '70.0.0.0/8' '104.0.0.0/8' \
  '131.0.0.0/8' '157.0.0.0/8' '168.0.0.0/24' '191.0.0.0/8' \
  '199.0.0.0/8' '207.0.0.0/8' '209.0.0.0/8' \
  --destination-ports 9000 22 443 53 445 \
  --action allow \
  --priority 1000

echo "Adding NTP rules to Firewall ${AZ_FW_NAME}"
az network firewall network-rule create \
  -g ${MC_AKS_RG} \
  -f ${AZ_FW_NAME} \
  --collection-name 'aksntp' \
  -n 'ntprules' \
  --protocols 'UDP' \
  --source-addresses '*' \
  --destination-addresses '91.189.91.157' '91.189.94.4' '91.189.89.198' '91.189.89.199' \
  --destination-ports 123 \
  --action allow \
  --priority 1100

# Create Default route to FW Private IP
if [ "${AKS_NET_TYPE}" = "kubenet" ]; then
  AKS_ROUTE_TABLE=$(az network route-table list -g ${MC_AKS_RG} --query '[].name' -o tsv)
else
  AKS_ROUTE_TABLE="${PREFIX}AKSRouteTable"
fi

az network route-table route create \
  -g ${MC_AKS_RG} \
  --name "DefaultEgressRoute" \
  --route-table-name ${AKS_ROUTE_TABLE} \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address ${AZ_FW_PVT_IP}