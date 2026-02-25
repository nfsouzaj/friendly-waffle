# Kubernetes & Azure CLI Cheat Sheet

---

## Cluster Management

**Get and set kubectl context:**

```sh
kubectl config get-contexts
kubectl config use-context SITADayLkyDev
```

**Check available AKS versions:**

```sh
az aks get-versions --location eastus --output table
```

**Get credentials for AKS clusters:**

```sh
# Dev
az aks get-credentials --subscription ed459897-1dc4-43c5-a753-7be586942a2d -n SITADayLkyDev -g SITADayLkyDev
# Ops Staging
az aks get-credentials --subscription 994744e4-70f2-4b40-8f9b-48ac40563208 -n OperationStaging -g SGS
# Sales (fill in values)
az aks get-credentials --subscription your-subscription-id -n your-cluster-name -g your-resource-group
```

**Update all deployments to current API version:**

```sh
kubectl get deployment --all-namespaces -o json | kubectl replace -f -
```

---

## Pod & Image Operations

**Get images from pods in a namespace:**

```sh
kubectl get pods -n smart-path-hub-2 -o=jsonpath="{range .items[*]}{.spec.containers[*].image}{'\n'}{end}"
```

**Get unique image count (sorted):**

```sh
kubectl get pods -n smart-path-hub-2 -o=jsonpath="{range .items[*]}{.spec.containers[*].image}{'\n'}{end}" | sort | uniq | wc -l
```

**Get unique images (ignore tag, all namespaces):**

```sh
kubectl get pods -A -o=jsonpath="{range .items[*]}{.spec.containers[*].image}{'\n'}{end}" | sort | awk -F: '{print $1}' | uniq
```

**Get CPU requests for pods in a namespace:**

```sh
kubectl -n smart-path-hub-2 get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.requests.cpu}{"\n"}{end}'
```

---

## Node Management

**Drain and cordon all agentpool nodes:**

```sh
kubectl get nodes -o custom-columns=:.metadata.name | grep agentpool | awk '{print $1}' | xargs -l1 kubectl drain --ignore-daemonsets --delete-emptydir-data
kubectl get nodes -o custom-columns=:.metadata.name | grep agentpool | awk '{print $1}' | xargs -l1 kubectl cordon
```

**List and label nodes:**

```sh
kubectl label --list nodes node01
kubectl label --list $(kubectl get nodes -o name)
kubectl label nodes node01 workload=production
```

---

## Pod Listing & Logs

**List pods with images (custom columns):**

```sh
kubectl get po -n sunnydale -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[*].image
```

**List pods sorted by memory usage:**

```sh
kubectl top pods --all-namespaces --sort-by=memory
```

**List all pods (all namespaces):**

```sh
kubectl get pods --all-namespaces
```

**Tail logs for a pod:**

```sh
kubectl logs -n default rabbitmq-0 --tail 5 -f
```

**Sort pods by creation time:**

```sh
kubectl get pods --sort-by=.metadata.creationTimestamp --all-namespaces
```

**Delete all pods in a namespace:**

```sh
kubectl delete pod -n abc --all
```

---

## RabbitMQ (RMQ)

**Port-forward RMQ service:**

```sh
kubectl port-forward --namespace default service/rabbitmq 15672
```

**Logs for RMQ pod:**

```sh
kubectl logs rabbitmq-2 -n default
```

**Open bash in RMQ pod:**

```sh
kubectl exec -it rabbitmq-0 -n default -- bash
```

**Shutdown RMQ node:**

```sh
rabbitmqctl --node rabbitmq-0 shutdown
rabbitmqctl --node rabbitmq-1 shutdown
```

**Check RMQ node status:**

```sh
rabbitmqctl status | grep node
```

**RMQ health check:**

```sh
rabbitmqctl node_health_check
```

**RMQ log level help:**  
[RabbitMQ Troubleshooting: Logging](https://www.rabbitmq.com/troubleshooting.html#logging)

---

## Pod Status & Conditions

**List restarted pods (all namespaces):**

```sh
kubectl get pods -A | awk '$5 != "0" {print $0}'
```

**Pod conditions:**

```sh
kubectl describe pod nginx | grep -i -A6 "Conditions"
```

**List pods not running:**

```sh
kubectl get pods --field-selector=status.phase!=Running --all-namespaces
```

---

## Helm

**Uninstall all Helm 3 releases in a namespace:**

```sh
helm3 ls -n abc --short | xargs -L1 helm uninstall -n rdu
```

**Uninstall all Helm 3 releases (all namespaces):**

```sh
helm3 ls --all-namespaces --short | xargs -L1 helm3 uninstall -n rdu
```

**Delete broken/pending Helm 2 charts:**

```sh
helm del $(helm ls --all | grep 'DELETED' | awk '{print $1}') --purge
```

---

## Azure Active Directory & ACR

**Get Object ID for AD Group:**

```sh
az ad group show --group devaksteam --query objectId -o tsv
```

**Login to Azure:**

```sh
az login
```

**Login to ACR (DEV/PRD):**

```sh
# DEV
TOKEN=$(az acr login --name xscntrlregdev --expose-token --subscription 9c855824-08d7-4a60-aa1d-49f264ef2726 --output tsv --query accessToken)
echo $TOKEN | docker login xscntrlregdev.azurecr.io --username 00000000-0000-0000-0000-000000000000 --password-stdin

# PRD
az account set --subscription 89dfabd1-917a-4fd4-90eb-623e6e47ebc5
TOKEN=$(az acr login --name xscntrlregprod --expose-token --subscription 89dfabd1-917a-4fd4-90eb-623e6e47ebc5 --output tsv --query accessToken)
echo $TOKEN | docker login xscntrlregprod.azurecr.io --username 00000000-0000-0000-0000-000000000000 --password-stdin
```

**Docker login with token:**

```sh
TOKEN_NAME=MyToken
TOKEN_PWD=your_token_password
echo $TOKEN_PWD | docker login --username $TOKEN_NAME --password-stdin myregistry.azurecr.io
```

**Import images to ACR:**

```sh
az acr import --name xscntrlregprod.azurecr.io --source k8s.gcr.io/ingress-nginx/controller:v1.1.1 --image ice-components/ingress-nginx/controller:v1.1.1
az acr import --name xscntrlregprod.azurecr.io --source ghcr.io/aquasecurity/trivy-db:latest --image ice-components/aquasecurity/tri
```

**Skopeo - inspect and copy images:**

```sh
skopeo inspect docker://docker.io/library/nginx:latest
skopeo inspect docker://mcr.microsoft.com/dotnet/aspnet:8.0
skopeo copy docker://docker.io/library/redis:7-alpine docker://myregistry.azurecr.io/redis:7-alpine
skopeo list-tags docker://docker.io/library/postgres | jq -r '.Tags[]'
```

**List artifacts in ACR:**

```sh
az acr login --name xscntrlregprod
az acr repository list --name xscntrlregprod --output table | grep bor
az acr repository show-tags --repository bor/sit/itp/ubuntu --name xscntrlregprod
```

**List file shares:**

```sh
az storage share list --account-key your_account_key --account-name your_account_name
```

**List all resources in a group:**

```sh
az resource list -g Nodes_SGSSandbox --subscription 994744e4-70f2-4b40-8f9b-48ac40563208
```

**Share files with service principal:**

```sh
az login --service-principal -u $(clientId) -p $(clientSecret) --tenant $(tenantId)
az aks get-credentials --subscription $(subscriptionId) -n SITADayLkyDev -g SITADayLkyDev
```

**Get volume name from PVC:**

```sh
volume=$(kubectl -n abc get pvc imageclaim -o=jsonpath='{.spec.volumeName}')
echo $volume
shareName="kubernetes-dynamic-$volume"
```

**Enable Azure File Share backup protection:**

```sh
az backup protection enable-for-azurefileshare --vault-name azurefilesvault --resource-group azurefiles --policy-name schedule1 --storage-account afsaccount --azure-file-share azurefiles --output table
az backup protection enable-for-azurefileshare --vault-name RecoveryVaultPREPRD --resource-group IdsMngmtBase --subscription 994744e4-70f2-4b40-8f9b-48ac40563208 --policy-name recovery-vault-policy --storage-account sitasgssandboxzigqb --azure-file-share kubernetes-dynamic-pvc-cdcafed6-1c8d-4c56-b67a-6d21487088eb --output table
```

**Get AKS credentials (admin):**

```sh
az aks get-credentials --name aks-hubspoke-eastus2-test-001 --resource-group spoke_core_poc --subscription ee24efef-dd2e-4b04-821b-56c071dcc3cc --admin
```

---

## Kubernetes RBAC & Authorization

**Approve/Deny CSR:**

```sh
kubectl certificate approve akshay
kubectl certificate deny agent-smith
```

**Check authorization mode:**

```sh
kubectl describe pod kube-apiserver-controlplane -n kube-system | grep auth
```

**Check if a user can list pods:**

```sh
kubectl get pods --as dev-user
```

**Create a Role and RoleBinding:**

```sh
kubectl create role developer --namespace=default --verb=list,create,delete --resource=pods
kubectl create rolebinding dev-user-binding --namespace=default --role=developer --user=dev-user
```

**Grant dev-user permissions to create deployments in blue namespace:**

```sh
kubectl create role developer --namespace=blue --verb=create --resource=deployments.apps,deployments.extensions
kubectl create rolebinding dev-user-binding --namespace=blue --role=developer --user=dev-user
```

---

## Node Affinity Example (YAML)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-affinity
spec:
  replicas: 6
  selector:
    matchLabels:
      run: nginx
  template:
    metadata:
      labels:
        run: nginx
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: app
                operator: In
                values:
                - qa
```
