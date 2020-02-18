
NUM="${RANDOM}"
PREFIX="mykube"
AZ_RG="${PREFIX}-aks-rg"
AZ_LOCATION="eastus2"
# Bastion VNET Configuration
AZ_BASTION_VNET_NAME="${PREFIX}-bastion-vnet"
AZ_BASTION_VNET="10.100.0.0/16"
AZ_VM_BASTION_SUBNET_NAME="vm-subnet"
AZ_VM_BASTION_SUBNET="10.100.0.0/24"
AZ_PROXY_BASTION_SUBNET_NAME="proxy-subnet"
AZ_PROXY_BASTION_SUBNET="10.100.1.0/24"
AZ_ONPREM_BASTION_SUBNET_NAME="onprem-subnet"
AZ_ONPREM_BASTION_SUBNET="10.100.255.0/24"
AZ_PE_BASTION_SUBNET_NAME="pe-subnet"
AZ_PE_BASTION_SUBNET="10.100.254.0/24"
AZ_BASTION_VM_NAME="bastionvm"

#AKS Configuration
AZ_AKS_NAME="${PREFIX}-aks-cluster"
AZ_AKS_VNET_NAME="${PREFIX}-aks-vnet"
AZ_AKS_SUBNET_NAME="aks-subnet"
AZ_PE_SUBNET_NAME="pe-subnet"
AZ_SVC_SUBNET_NAME="svc-subnet"
AZ_ACI_SUBNET_NAME="aci-subnet"
AZ_FW_SUBNET_NAME="AzureFirewallSubnet"
AZ_FW_PUB_IP_NAME="${PREFIX}AKSFWPublicIP"
AZ_FW_IPCONFIG_NAME="${PREFIX}AKSFWIPConfig"
AZ_FW_NAME="${PREFIX}AKSFirewall"
AZ_FW_ROUTE_TABLE="${PREFIX}fwroutetable"
AZ_FW_ROUTE_NAME="${PREFIX}fwroute"

AZ_PE_TO_AKS_MASTER="${PREFIX}.aks-cluster.pe"
AZ_ACCESS_TOKEN=$(az account get-access-token -o tsv --query 'accessToken')
AZ_SUB_ID=$(az account show -o tsv --query 'id')

###############################################################################
# AKS_NET_TYPE="kubenet" for kubenet (Internal NATed Pod IP)                  #
# AKS_NET_TYPE="azure" for CNI (Azure VNET Pod IP)                            #
###############################################################################
AKS_NET_TYPE="kubenet"
###############################################################################

if [ "${AKS_NET_TYPE}" = "kubenet" ]; then
  AZ_AKS_VNET="10.0.0.0/8"
  AZ_AKS_SUBNET="10.240.0.0/24"
  AZ_SVC_SUBNET="10.250.0.0/24"
  AZ_ACI_SUBNET="10.250.1.0/24"
  AZ_PE_SUBNET="10.250.254.0/24"
  AZ_FW_SUBNET="10.250.255.0/24"
else
  AZ_AKS_VNET="10.0.0.0/8"
  AZ_AKS_SUBNET="10.240.0.0/16"
  AZ_SVC_SUBNET="10.250.0.0/24"
  AZ_ACI_SUBNET="10.250.1.0/24"
  AZ_PE_SUBNET="10.250.254.0/24"
  AZ_FW_SUBNET="10.250.255.0/24"
fi
