# Kubernetes & Azure CLI Cheat Sheet

## Pod & Image Operations

- **Get images from pods in a namespace:**
  kubectl get pods -n smart-path-hub-2 -o=jsonpath="{range .items[*]}{.spec.containers[*].image}{'\n'}{end}"

- **Get unique image count (sorted):**
  kubectl get pods -n smart-path-hub-2 -o=jsonpath="{range .items[*]}{.spec.containers[*].image}{'\n'}{end}" | sort | uniq | wc -l

- **Get unique images (ignore tag, all namespaces):**
  kubectl get pods -A -o=jsonpath="{range .items[*]}{.spec.containers[*].image}{'\n'}{end}" | sort | awk -F: '{print $1}' | uniq

- **Get CPU requests for pods in a namespace:**
  kubectl -n smart-path-hub-2 get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.requests.cpu}{"\n"}{end}'

## Node Management

- **Drain all agentpool nodes:**
  kubectl get nodes -o custom-columns=:.metadata.name | grep agentpool | awk '{print $1}' | xargs -l1 kubectl drain --ignore-daemonsets --delete-emptydir-data

- **Cordon all agentpool nodes:**
  kubectl get nodes -o custom-columns=:.metadata.name | grep agentpool | awk '{print $1}' | xargs -l1 kubectl cordon

- **List node labels:**
  kubectl label --list nodes node01
  kubectl label --list $(kubectl get nodes -o name)

- **Label a node:**
  kubectl label nodes node01 workload=production

## Pod Listing & Logs

- **List pods with images (custom columns):**
  k get po -n sunnydale -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[*].image

- **List pods sorted by memory usage:**
  kubectl top pods --all-namespaces --sort-by=memory

- **List all pods (all namespaces):**
  kubectl get pods --all-namespaces

- **Tail logs for a pod:**
  kubectl logs -n default rabbitmq-0 --tail 5 -f

- **Sort pods by creation time:**
  kubectl get pods --sort-by=.metadata.creationTimestamp --all-namespaces

- **Delete all pods in a namespace:**
  kubectl delete pod -n abc --all

## RabbitMQ (RMQ)

- **Port-forward RMQ service:**
  kubectl port-forward --namespace default service/rabbitmq 15672

- **Logs for RMQ pod:**
  kubectl logs rabbitmq-2 -n default

- **Open bash in RMQ pod:**
  kubectl exec -it rabbitmq-0 -n default -- bash

- **Shutdown RMQ node:**
  rabbitmqctl --node rabbitmq-0 shutdown
  rabbitmqctl --node rabbitmq-1 shutdown

- **Check RMQ node status:**
  rabbitmqctl status | grep node

- **RMQ health check:**
  rabbitmqctl node_health_check

- **RMQ log level help:**
  [https://www.rabbitmq.com/troubleshooting.html#logging](https://www.rabbitmq.com/troubleshooting.html#logging)

## Pod Status & Conditions

- **List restarted pods (all namespaces):**
  kubectl get pods -A | awk '$5 != "0" {print $0}'

- **Pod conditions:**
  kubectl describe pod nginx | grep -i -A6 "Conditions"

- **List pods not running:**
  kubectl get pods --field-selector=status.phase!=Running --all-namespaces

## Helm

- **Uninstall all Helm 3 releases in a namespace:**
  helm3 ls -n abc --short | xargs -L1 helm uninstall -n rdu

- **Uninstall all Helm 3 releases (all namespaces):**
  helm3 ls --all-namespaces --short | xargs -L1 helm3 uninstall -n rdu

- **Delete broken/pending Helm 2 charts:**
  helm del $(helm ls --all | grep 'DELETED' | awk '{print $1}') --purge

## Azure AKS

- **Get credentials for AKS clusters:**

  **Dev:**

  az aks Get-Credentials --subscription ed459897-1dc4-43c5-a753-7be586942a2d -n SITADayLkyDev -g SITADayLkyDev

  **Ops Staging:**

  az aks Get-Credentials --subscription 994744e4-70f2-4b40-8f9b-48ac40563208 -n OperationStaging -g SGS

  **Sales (fill in values):**

  az aks Get-Credentials --subscription \<id\> -n \<name\> -g \<group\>

- **Check available k8s versions in Azure:**

  az aks get-versions --location eastus --output table

## Context Management

- **Get and set kubectl context:**
  kubectl config get-contexts
  kubectl config use-context SITADayLkyDev

## API Version Migration

- **Update all deployments to current API version:**
  kubectl get deployment --all-namespaces -o json | kubectl replace -f -

## Deployment & Scaling

- **Create deployment:**
  kubectl create deployment --image=nginx nginx
  kubectl create deployment --image=nginx blue

- **Scale deployment:**
  kubectl scale --replicas=3 deployment/blue

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
