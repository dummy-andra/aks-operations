AKS Operations
==============

AKS operational tasks overview.

Prerequisities
--------------

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* [k6](https://k6.io/)

Create an AKS cluster
---------------------

```sh
source ./aks-ops-env.sh

az group create -n $RG_NAME -l $LOCATION
```

```sh
az aks get-versions -l australiaeast -o table

KubernetesVersion    Upgrades
-------------------  -------------------------
1.20.2(preview)      None available
1.19.7               1.20.2(preview)
1.19.6               1.19.7, 1.20.2(preview)
1.18.14              1.19.6, 1.19.7
1.18.10              1.18.14, 1.19.6, 1.19.7
1.17.16              1.18.10, 1.18.14
1.17.13              1.17.16, 1.18.10, 1.18.14
```

Create a basic cluster:

```sh
az aks create \
    -n $CLUSTER_NAME \
    -g $RG_NAME \
    -l $LOCATION \
    -k $K8S_VERSION \
    -c $NODE_COUNT \
    -a $AKS_ADD_ONS \
    --generate-ssh-keys \
    --enable-managed-identity \
    --enable-aad \
    --enable-azure-rbac \
    --auto-upgrade-channel $UPGRADE_CHANNEL \
    -z 1 2 3

az aks list -o table
az aks get-credentials -n $CLUSTER_NAME -g $RG_NAME
az aks install-cli # --install-location /path/to/kubectl

az aks show -n $CLUSTER_NAME -g $RG_NAME -o table  # control plane info
kubectl get nodes -o wide                           # worker node info
```

Open VS Code, click the Kubernetes icon and under clusters you should see the new cluster.
You can also [create new](https://code.visualstudio.com/docs/azure/kubernetes) or add existing clusters via VSCode.

Scale cluster
-------------

```sh
az aks show -n $CLUSTER_NAME -g $RG_NAME --query agentPoolProfiles[0].name
az aks scale -n $CLUSTER_NAME -g $RG_NAME --node-count 3 --nodepool-name nodepool1
```

Manually Upgrade cluster
------------------------

Upgrade control plane:

```sh
UPGRADE_TO_VERSION=1.19.6

az aks upgrade -n aks-ops-cbx1 -g aks-ops -k $UPGRADE_TO_VERSION --control-plane-only --yes
```

Upgrade node pools:

```sh
az aks show -n aks-ops-cbx1 -g aks-ops -o table  # control plane info
kubectl get nodes -o wide                        # worker node info

az aks nodepool upgrade --cluster-name aks-ops-cbx1 --resource-group aks-ops -k $UPGRADE_TO_VERSION --name nodepool1
kubectl get nodes -o wide -w
```

Or, use a blue/green node pool strategy:

* Create new node pool
* Taint old node pool
* Drain old node pool
* Delete old node pool

See [Walkthrough of automating AKS upgrades](https://github.com/cloudnativegbb/aks-upgrades) for sample scripts.

Check the Azure Portal while running these commands.

Deploy Application
------------------

* Deploy Ingress Controller

Follow steps in: https://github.com/clarenceb/traefik-ingress-example.git

* Deploy app

```sh
kubectl create ns azure-vote
# Update apps/azure-vote/azure-vote-ingress.yaml with <DNSNAME>.<LOCATION> value
kubectl apply -f apps/azure-vote -n azure-vote
```

Browse to: `https://<DNSNAME>.<LOCATION>.cloudapp.azure.com`

Generate some traffic:

```sh
VOTE_URL=https://<DNSNAME>.<LOCATION>.cloudapp.azure.com/
k6 run --vus 100 --duration 30s -e VOTE_URL=$VOTE_URL generate-votes-test.js
```

Introduce some deliberate issues
--------------------------------

* Make sure some load has been generated a few mins earlier (~5+ mins).
* Run the Gremlins in `gremlins/` directory, one at a time and diagnose the issue.

Diagnosing issues
-----------------

### Examine layout of cluster

* Azure Portal
* Kubernetes Dashboard
* Octant
* KubeView
* kubectl
* Examine - nodes, namespaces, deployments, services, ingress, pods, etc.

### Examine cluster, nodes, controllers, containers in Container Insights (Azure Portal)

* Check the container insights views and live data
* Select `Logs` from `Monitoring` side navigation menu
* Enter some KQL queries for Kubernetes Services using tables `AzureDiagnostics`, `AzureActivity`, `ContainerActivity`, `ContainerLog`, `KubeEvents`

```kql
AzureDiagnostics
| where Category == 'kube-audit'
| extend log=parse_json(log_s)
| where log.verb == 'delete'
| project log
| limit 100
```

```kql
KubeEvents
| where TimeGenerated > ago(24h)
| where Reason in ("Failed")
| summarize count() by Reason, bin(TimeGenerated, 5m)
| render areachart
```

### Examine deployments, pods, services in VS Code via Kubernetes (vscode-kubernetes-tools) extension

* Select the cluster you want to use
* Select namespace `azure-vote`
* Naviate to Workloads / Deployments
    * Double click `azure-vote-front` deployment to see YAML
    * Drill down to pod for `azure-vote-front`
    * Double click `azure-vote-front` pod to see YAML
    * Select `Describe` from context menu
    * Select `Terminal` from context menu - `ps -ef`, `top`, `exit`
    * Select `Follow Logs` from context menu - vote a few times to crate logs entries
* Naviate to Network / Services
* Naviate to Network / Ingress

### Collect logs with Periscope

```sh
az storage account create -n aksperiscopedatacbx -g aks-ops -l australiaeast --sku Standard_LRS --kind StorageV2 --access-tier Hot
az aks kollect -g aks-ops -n aks-ops-cbx1 --storage-account aksperiscopedatacbx --container-logs azure-vote
```

Cleanup Periscope from cluster:

```sh
kubectl delete -f https://raw.githubusercontent.com/Azure/aks-periscope/master/deployment/aks-periscope.yaml -n aks-periscope
```

### Diff Kubernetes objects in namespace vs git repo

```sh
kubectl diff -f apps/azure-vote/ -n azure-vote
```

TODO
----

Issues:

* No ACR pull secret/SP role grant acrpull permission
* Exceed limit/quota constraint - num services, GB RAM, CPU (e.g. mc - millicores, set low and see container insights CPU flame chart)
* Deploying without node selectors when you have a windows pool
* AKS 1.16 using deprecated objects/versions
* Namespace deletion stuck (finalizer issue)
* Removal of labels/annotations on VMSS nodes (upgrade issues, skip version)
* Ingress misconfiguration (host, path, service name or port, etc.)
* HPA/CAS settings incorrect - pending pods, etc.
* Namespace limits and/or quotas set too low

Other topics:

* Multiple node pools
* Windows node pools
* [Drain/cordon workloads](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)
* [Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)

Resources
---------

* [AKS troubleshooting](https://docs.microsoft.com/en-us/azure/aks/troubleshooting)
