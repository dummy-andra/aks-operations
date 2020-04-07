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
az group create -n aks-ops -l australiaeast
```

```sh
az aks get-versions -l australiaeast -o table

KubernetesVersion    Upgrades
-------------------  -----------------------
1.17.3(preview)      None available
1.16.7               1.17.3(preview)
1.15.10              1.16.7
1.15.7               1.15.10, 1.16.7
1.14.8               1.15.7, 1.15.10
1.14.7               1.14.8, 1.15.7, 1.15.10
```

Create a basic cluster:

```sh
az aks create -n aks-ops-cbx1 -g aks-ops -l australiaeast -k 1.15.7 -c 2 -a monitoring --generate-ssh-keys
az aks list -o table
az aks get-credentials -n aks-ops-cbx1 -g aks-ops
az aks install-cli # --install-location /path/to/kubectl

az aks show -n aks-ops-cbx1 -g aks-ops -o table  # control plane info
kubectl get nodes -o wide                        # worker node info
```

Scale cluster
-------------

```sh
az aks show -g aks-ops -n aks-ops-cbx1 --query agentPoolProfiles[0].name
az aks scale -g aks-ops -n aks-ops-cbx1 --node-count 3 --nodepool-name nodepool1
```

Upgrade cluster
---------------

```sh
az aks upgrade -n aks-ops-cbx1 -g aks-ops -k 1.15.10 --control-plane-only --yes

az aks show -n aks-ops-cbx1 -g aks-ops -o table  # control plane info
kubectl get nodes -o wide                        # worker node info

az aks nodepool upgrade --cluster-name aks-ops-cbx1 --resource-group aks-ops -k 1.15.10 --name nodepool1
kubectl get nodes -o wide -w
```

Check the Azure Portal while running these commands.

Deploy Application
------------------

* Deploy Ingress Controller

Follow steps in: https://github.com/clarenceb/traefik-ingress-example.git

* Deploy app

```sh
kubectl ns create azure-vote
# Update apps/azure-vote/azure-vote-ingress.yaml with <DNSNAME>.<LOCATION> value
kubectl apply -f apps/azure-vote -n azure-vote
```

Browse to: `https://<DNSNAME>.<LOCATION>.cloudapp.azure.com`

Generate some traffic:

```sh
k6 run --vus 100 --duration 30s -e VOTE_URL=https://<DNSNAME>.<LOCATION>.cloudapp.azure.com/ generate-votes-test.js
```

Introduce some deliberate issues
--------------------------------

* Make sure some load has been generated a few mins ealrier (~5+ mins).
* Kill some pods

TODO:
- No ACR pull secret/SP role grant acrpull permission
- Exceed limit/quota constraint - num services, GB RAM, CPU (e.g. mc - millicores, set low and see container insights CPU flame chart)
- Deploying without node selectors when you have a windows pool
- AKS 1.16 using deprecated objects/versions
- Namespace deletion stuck (finalizer issue)
- Removal of labels/annotations on VMSS nodes (upgrade issues, skip version)
- Ingress misconfiguration (host, path, service name or port, etc.)

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
* Select `Logs` from `Moniotring` side navigation menu
* Enter some KQL queries for Kubernetes Services using tables `AzureDiagnostics`, `AzureActivity`, `ContainerActivity`, `ContainerLog`, `KubeEvents`

### Examine deployments, pods, services in VS Code via Kubernetes (vscode-kubernetes-tools) extension

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

TODO

TODO
----

* Multiple node pools
* Windows node pools
* [Drain/cordon workloads](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)
* [Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)

Resources
---------

* [AKS troubleshooting](https://docs.microsoft.com/en-us/azure/aks/troubleshooting)
