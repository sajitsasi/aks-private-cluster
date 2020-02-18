#!/bin/bash

. ./source_vars.sh

echo "Deleting resource group ${AZ_RG}..."
az group delete --name ${AZ_RG} -y
echo "done!"
