#!/bin/bash

CREATE_AKS_CLUSTER="$(pwd)/00create_aks_cluster.sh"
CREATE_FW_ROUTE="$(pwd)/01create_fw_route.sh"
CREATE_BASTION="$(pwd)/02create_bastion.sh"
if [ -x ${CREATE_AKS_CLUSTER} ]; then
  echo "Calling ${CREATE_AKS_CLUSTER}"
  ${CREATE_AKS_CLUSTER}
  if [ $? -ne 0 ]; then
    echo "ERROR: running ${CREATE_AKS_CLUSTER}"
    exit 1
  fi
else
  echo "ERROR: could not find ${CREATE_AKS_CLUSTER}"
  exit 1
fi

if [ -x ${CREATE_FW_ROUTE} ]; then
  echo "Calling ${CREATE_FW_ROUTE}"
  ${CREATE_FW_ROUTE}
  if [ $? -ne 0 ]; then
    echo "ERROR: running ${CREATE_FW_ROUTE}"
    exit 1
  fi
else
  echo "ERROR: could not find ${CREATE_FW_ROUTE}"
  exit 1
fi

if [ -x ${CREATE_BASTION} ]; then
  echo "Calling ${CREATE_BASTION}"
  ${CREATE_BASTION}
  if [ $? -ne 0 ]; then
    echo "ERROR: running ${CREATE_BASTION}"
    exit 1
  fi
else
  echo "Not creating bastion resources..."
  exit 0
fi