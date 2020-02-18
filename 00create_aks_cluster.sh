#!/bin/bash

. ./source_vars.sh

# Preview Extensions
az extension add --name aks-preview
az extension update --name aks-preview
az feature register --name AKSPrivateLinkPreview --namespace Microsoft.ContainerService

declare -i count=30
echo -n "Checking for AKSPrivateLinkPreview registration"
while [ ${count} -gt 1 ]; do
  reg=$(az feature list -o tsv --query "[?contains(name, 'Microsoft.ContainerService/AKSPrivateLinkPreview')].{State:properties.state}")
  if [ "${reg}" = "Registered" ]; then
    break
  else
    count=$(( $count - 1 ))
    echo -n "."
    sleep 4
  fi
done

if [ ! "${reg}" = "Registered" ]; then
  echo -e "\nERROR: AKSPrivateLinkPreview not registered!!!\n"
  exit 1
else
  echo -e "\nAKSPrivateLinkPreview registered"
  az provider register --namespace Microsoft.ContainerService
  az provider register --namespace Microsoft.Network
fi

# Create Resource Group
echo "Creating resource group ${AZ_RG} in ${AZ_LOCATION}"
az group create -n ${AZ_RG} -l ${AZ_LOCATION} &> /dev/null

echo "Creating AKS cluster ${AZ_AKS_NAME} with network plugin ${AKS_NET_TYPE}..."
az aks create -n ${AZ_AKS_NAME} \
    -g ${AZ_RG} \
    --load-balancer-sku standard \
    --enable-private-cluster \
    --node-count 2 \
    --node-vm-size Standard_DS1_v2 \
    --docker-bridge-address 172.17.0.1/16 \
    --network-plugin ${AKS_NET_TYPE} \
    --enable-addons monitoring \
    --generate-ssh-keys \
    --location ${AZ_LOCATION}
echo "Done creating AKS cluster ${AZ_AKS_NAME}"
MC_AKS_RG=$(az aks show -g ${AZ_RG} --name ${AZ_AKS_NAME} --query nodeResourceGroup -o tsv)
MC_AKS_VNET_NAME=$(az network vnet list -g ${MC_AKS_RG} --query '[*].name' -o tsv)
AKS_SCALE_SET_NAME=$(az vmss list --resource-group ${MC_AKS_RG} --query [0].name -o tsv)
az vmss extension set \
  -g ${MC_AKS_RG} \
  --vmss-name ${AKS_SCALE_SET_NAME} \
  --name VMAccessForLinux \
  --publisher Microsoft.OSTCExtensions \
  --version 1.4 \
  --protected-settings "{\"username\":\"azureuser\", \"ssh_key\":\"$(cat ~/.ssh/id_rsa.pub)\"}"

az vmss update-instances \
  --instance-ids '*' \
  -g ${MC_AKS_RG} \
  --name ${AKS_SCALE_SET_NAME}

# Create AKS VNET 
echo "Creating AKS VNET and subnets..."
az network vnet subnet create \
  -g ${MC_AKS_RG} \
  --vnet-name ${MC_AKS_VNET_NAME} \
  --name ${AZ_SVC_SUBNET_NAME} \
  --address-prefix ${AZ_SVC_SUBNET} &> /dev/null

az network vnet subnet create \
  -g ${MC_AKS_RG} \
  --vnet-name ${MC_AKS_VNET_NAME} \
  --name ${AZ_PE_SUBNET_NAME} \
  --address-prefix ${AZ_PE_SUBNET} &> /dev/null

az network vnet subnet create \
  -g ${MC_AKS_RG} \
  --vnet-name ${MC_AKS_VNET_NAME} \
  --name ${AZ_ACI_SUBNET_NAME} \
  --address-prefix ${AZ_ACI_SUBNET} &> /dev/null

az network vnet subnet create \
  -g ${MC_AKS_RG} \
  --vnet-name ${MC_AKS_VNET_NAME} \
  --name ${AZ_FW_SUBNET_NAME} \
  --address-prefix ${AZ_FW_SUBNET} &> /dev/null
