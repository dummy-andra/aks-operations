#!/bin/bash

export LOCATION=australiaeast
export K8S_VERSION="$(az aks get-versions --location $LOCATION | jq -r ".orchestrators[] | select(.default==true) | .orchestratorVersion")"
export RG_NAME=aks-demos
export CLUSTER_NAME=aks-ops
export NODE_COUNT=2
export AKS_ADD_ONS=monitoring
export UPGRADE_CHANNEL=stable
