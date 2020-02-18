# Create Private AKS Cluster with Firewall
## Overview

Create a private Azure Kubernetes Service cluster with an Azure Firewall and access kubectl commands (Control Plane) through a private endpoint.

## Pre-requisites
The Azure CLI version 2.0.77 or later, and the Azure CLI AKS Preview extension version 0.4.18

## Goals of the Lab
1. Create a private AKS cluster.
2. Create an Azure Firewall & Modify Route Table
3. Create Bastion Network with access via Private Endpoint to AKS Cluster

## Auto-create Cluster, Firewall, Bastion VNET, and Private Endpoint in Bastion VNET
1. Edit ```source_vars.sh``` file and update ```AKS_NET_TYPE``` variable to choose between [kubenet](https://docs.microsoft.com/en-us/azure/aks/concepts-network#kubenet-basic-networking) and [CNI](https://docs.microsoft.com/en-us/azure/aks/concepts-network#azure-cni-advanced-networking)
2. Optionally, update the ```PREFIX```, ```AZ_FW_FQDNS```, ```AZ_FW_DST_IPS```, ```AZ_FW_NTP_IPS``` variables
3. Call the ```./deploy_cluster.sh``` script to automatically deploy the cluster
4. The script will take some time to run (20-30 minutes) and after successful completion will have:
   * Created an AKS cluster
   * Created extra subnets in the AKS VNET
   * Created an Azure Firewall with the default route from the cluster pointing to the Azure Firewall:
   * Created a Bastion VNET with a Private Endpoint to the AKS Cluster Control Plane
   * Created a VM named ```${AZ_BASTION_VM_NAME}``` with a system managed identity with Contributor role over the AKS Resource Group


## Commands to run after Cluster, Firewall, Bastion etc. created
1. Login to VM
```
#### Get Public IP of VM ####
. ./source_vars.sh
vm_public_ip=$(az vm show -d -g ${AZ_RG} --name ${AZ_BASTION_VM_NAME} --query 'publicIps' -o tsv)
#### Copy variable definitions to bastionvm ####
scp ./source_vars.sh user@${vm_public_ip}:./
#### SSH to bastionvm ####
ssh user@${vm_public_ip}
```

2. Install tools and login with Azure
```
#### Update/Upgrade ####
sudo apt-get update
sudo apt-get upgrade -y
#### Install AZ CLI and Login with MSI ####
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login --identity
#### Install kubectl ####
sudo az aks install-cli
```

3. Get AKS Credentials
```
#### Write AKS credentials ####
. ./source_vars.sh
kube_file="/tmp/kube${RANDOM}.config"
az aks get-credentials --name ${AZ_AKS_NAME} -g ${AZ_RG} -f ${kube_file}
#### Get FQDN from kube config file ####
AKS_FQDN=$(cat ${kube_file} | grep "server:" | awk '{print $2}' | sed -e 's/:443//g' -e 's/https:\/\///g')
/bin/rm -rf ${kube_file}
#### Add FQDN-->Private Endpoint translation in /etc/hosts ####
AZ_PE_RESOURCE_ID=$(az network private-endpoint show --name ${AZ_PE_TO_AKS_MASTER} -g ${AZ_RG} --query 'networkInterfaces[0].id' -o tsv)
AKS_MASTER_PE_IP=$(az resource show --ids ${AZ_PE_RESOURCE_ID} --query 'properties.ipConfigurations[0].properties.privateIPAddress' -o tsv)
sudo echo "${AKS_MASTER_PE_IP} ${AKS_FQDN}" | sudo tee -a /etc/hosts
#### Add AKS credentials in ~/.kube/config ####
az aks get-credentials --name ${AZ_AKS_NAME} -g ${AZ_RG} --overwrite-existing
#### Run kubectl commands ####
kubectl get nodes -o wide
```

4. Enable SSH Access to Nodes (Optional)
```
#### Add VMSS Extension from Bastion VM ####
MC_AKS_RG=$(az aks show -g ${AZ_RG} --name ${AZ_AKS_NAME} --query nodeResourceGroup -o tsv)
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
#### Start aks-ssh pod to ssh to nodes and install openssh-client ####
kubectl run --generator=run-pod/v1 -it --rm aks-ssh --image=debian
apt-get update && apt-get install openssh-client -y
#### In another window copy SSH id_rsa ####
kubectl cp ~/.ssh/id_rsa $(kubectl get pod -l run=aks-ssh -o jsonpath='{.items[0].metadata.name}'):/id_rsa
#### In SSH session ####
chmod 0600 /id_rsa
ssh -i /id_rsa azureuser@<node_ip>
