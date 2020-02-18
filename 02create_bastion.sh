#!/bin/bash

. ./source_vars.sh

MC_AKS_RG=$(az aks show -g ${AZ_RG} --name ${AZ_AKS_NAME} --query nodeResourceGroup -o tsv)
AKS_RESOURCE_ID=$(az aks show --name ${AZ_AKS_NAME} --resource-group ${AZ_RG} --query 'id' -o tsv)
SCALE_SET_NAME=$(az vmss list --resource-group ${AZ_RG} --query [0].name -o tsv)

# Create Bastion VNET - comment out if this is already done
echo "Creating Bastion VNET and subnets..."
az network vnet create \
  -g ${AZ_RG} \
  --name ${AZ_BASTION_VNET_NAME} \
  --address-prefixes ${AZ_BASTION_VNET} \
  --subnet-name ${AZ_VM_BASTION_SUBNET_NAME} \
  --subnet-prefix ${AZ_VM_BASTION_SUBNET} &> /dev/null

az network vnet subnet create \
  -g ${AZ_RG} \
  --vnet-name ${AZ_BASTION_VNET_NAME} \
  --name ${AZ_PROXY_BASTION_SUBNET_NAME} \
  --address-prefix ${AZ_PROXY_BASTION_SUBNET} &> /dev/null

az network vnet subnet create \
  -g ${AZ_RG} \
  --vnet-name ${AZ_BASTION_VNET_NAME} \
  --name ${AZ_ONPREM_BASTION_SUBNET_NAME} \
  --address-prefix ${AZ_ONPREM_BASTION_SUBNET} &> /dev/null

az network vnet subnet create \
  -g ${AZ_RG} \
  --vnet-name ${AZ_BASTION_VNET_NAME} \
  --name ${AZ_PE_BASTION_SUBNET_NAME} \
  --address-prefix ${AZ_PE_BASTION_SUBNET} &> /dev/null

az network vnet subnet update \
  -g ${AZ_RG} \
  --name ${AZ_PE_BASTION_SUBNET_NAME} \
  --vnet-name ${AZ_BASTION_VNET_NAME} \
  --disable-private-endpoint-network-policies true
echo "Done creating Bastion VNET and subnets..."

# Create Private Endpoint in pe-subnet of bastion to AKS cluster
az network private-endpoint create \
  -g ${AZ_RG} \
  --name ${AZ_PE_TO_AKS_MASTER} \
  --vnet-name ${AZ_BASTION_VNET_NAME} \
  --subnet ${AZ_PE_BASTION_SUBNET_NAME} \
  --private-connection-resource-id ${AKS_RESOURCE_ID} \
  --group-ids management \
  --connection-name "${PREFIX}AKSClusterConnection"

AZ_PE_RESOURCE_ID=$(az network private-endpoint show --name ${AZ_PE_TO_AKS_MASTER} -g ${AZ_RG} --query 'networkInterfaces[0].id' -o tsv)
AKS_MASTER_PE_IP=$(az resource show --ids ${AZ_PE_RESOURCE_ID} --query 'properties.ipConfigurations[0].properties.privateIPAddress' -o tsv)
echo "PE IP Address is ${AKS_MASTER_PE_IP}"

az vm create \
  -g ${AZ_RG} \
  -n ${AZ_BASTION_VM_NAME} \
  --assign-identity \
  --image UbuntuLTS \
  --vnet-name ${AZ_BASTION_VNET_NAME} \
  --subnet ${AZ_ONPREM_BASTION_SUBNET_NAME} \
  --generate-ssh-keys \
  --size Standard_DS1_v2

AZ_BASTION_VM_IP=$(az vm show -d -g ${AZ_RG} --name ${AZ_BASTION_VM_NAME} --query 'publicIps' -o tsv)
echo "${AZ_BASTION_VM_NAME} Public IP is ${AZ_BASTION_VM_IP}"
AZ_BASTION_VM_SPID=$(az resource list -n ${AZ_BASTION_VM_NAME} --query [*].identity.principalId -o tsv)
az role assignment create \
  --assignee ${AZ_BASTION_VM_SPID} \
  --role 'Contributor' \
  --scope $(az group show -n ${MC_AKS_RG} --query 'id' -o tsv)

az role assignment create \
  --assignee ${AZ_BASTION_VM_SPID} \
  --role 'Contributor' \
  --scope $(az group show -n ${AZ_RG} --query 'id' -o tsv)