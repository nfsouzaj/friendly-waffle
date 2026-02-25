#!/bin/bash
#
# K8s Cluster Health Overview Script
# Quickly assess cluster state, problematic pods, node issues, and resources
#

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Separators
SECTION_SEP="═══════════════════════════════════════════════════════════════════════════════"
SUBSEC_SEP="───────────────────────────────────────────────────────────────────────────────"

print_header() {
    echo -e "\n${BLUE}${SECTION_SEP}${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BLUE}${SECTION_SEP}${NC}\n"
}

print_subheader() {
    echo -e "\n${YELLOW}▶ $1${NC}"
    echo -e "${SUBSEC_SEP}"
}

print_warning() {
    echo -e "${YELLOW}⚠  $1${NC}"
}

print_error() {
    echo -e "${RED}✖  $1${NC}"
}

print_ok() {
    echo -e "${GREEN}✔  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ  $1${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    exit 1
fi

echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════════════════════════╗"
echo "  ║           K8S CLUSTER HEALTH OVERVIEW                        ║"
echo "  ║           $(date '+%Y-%m-%d %H:%M:%S')                              ║"
echo "  ╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================================
# CLUSTER INFO
# ============================================================================
print_header "CLUSTER INFORMATION"

CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo "unknown")
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "unknown")
K8S_VERSION=$(kubectl version --short 2>/dev/null | grep "Server" || kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo "unknown")

echo -e "Context:     ${BOLD}$CONTEXT${NC}"
echo -e "Cluster:     ${BOLD}$CLUSTER_NAME${NC}"
echo -e "Server:      ${BOLD}$SERVER${NC}"
echo -e "K8s Version: ${BOLD}$K8S_VERSION${NC}"

# ============================================================================
# NODE STATUS
# ============================================================================
print_header "NODE STATUS"

print_subheader "All Nodes"
kubectl get nodes -o wide 2>/dev/null || kubectl get nodes

print_subheader "Node Conditions (Problems Only)"
NOT_READY_NODES=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.status=="False")]}{.type}={.status} {end}{range .status.conditions[?(@.type=="Ready")]}{.type}={.status}{end}{"\n"}{end}' 2>/dev/null | grep -v "Ready=True" || true)

if [ -n "$NOT_READY_NODES" ]; then
    print_warning "Nodes with issues:"
    echo "$NOT_READY_NODES"
else
    print_ok "All nodes are Ready"
fi

print_subheader "Node Resource Allocation"
kubectl top nodes 2>/dev/null || print_info "Metrics server not available - kubectl top nodes failed"

print_subheader "Node Taints"
kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].effect' 2>/dev/null | grep -v "<none>" || print_ok "No node taints found"

# ============================================================================
# POD STATUS - PROBLEMS
# ============================================================================
print_header "PROBLEMATIC PODS"

print_subheader "Pods NOT Running/Completed (all namespaces)"
PROBLEM_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded -o wide 2>/dev/null || true)
if [ -n "$PROBLEM_PODS" ] && [ "$(echo "$PROBLEM_PODS" | wc -l)" -gt 1 ]; then
    echo "$PROBLEM_PODS"
else
    print_ok "No pods in problematic phase"
fi

print_subheader "Pods with Restarts > 5"
kubectl get pods --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase' 2>/dev/null | awk 'NR==1 || ($3 != "<none>" && $3 > 5)' | grep -v "^NAMESPACE" | head -20 || print_ok "No pods with excessive restarts"

print_subheader "CrashLoopBackOff / Error Pods"
CRASH_PODS=$(kubectl get pods --all-namespaces 2>/dev/null | grep -E "CrashLoopBackOff|Error|ImagePullBackOff|ErrImagePull|CreateContainerError|InvalidImageName" || true)
if [ -n "$CRASH_PODS" ]; then
    print_error "Pods in error states:"
    echo "$CRASH_PODS"
else
    print_ok "No pods in crash/error state"
fi

print_subheader "Pending Pods"
PENDING_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o wide 2>/dev/null || true)
if [ -n "$PENDING_PODS" ] && [ "$(echo "$PENDING_PODS" | wc -l)" -gt 1 ]; then
    print_warning "Pending pods found:"
    echo "$PENDING_PODS"
else
    print_ok "No pending pods"
fi

print_subheader "Pods Not Ready (Running but containers not ready)"
kubectl get pods --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.status.phase == "Running") | select(.status.containerStatuses[]?.ready == false) | "\(.metadata.namespace)\t\(.metadata.name)\t\(.status.containerStatuses[].ready)"' 2>/dev/null | column -t || print_ok "All running pods are ready"

# ============================================================================
# RESOURCE USAGE
# ============================================================================
print_header "RESOURCE USAGE"

print_subheader "Top CPU-consuming Pods"
kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -15 || print_info "Metrics server not available"

print_subheader "Top Memory-consuming Pods"
kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -15 || print_info "Metrics server not available"

# ============================================================================
# DEPLOYMENTS / REPLICASETS / DAEMONSETS STATUS
# ============================================================================
print_header "WORKLOAD STATUS"

print_subheader "Deployments Not Fully Available"
kubectl get deployments --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.status.availableReplicas != .status.replicas or .status.availableReplicas == null) | "\(.metadata.namespace)\t\(.metadata.name)\t\(.status.availableReplicas // 0)/\(.status.replicas // 0)"' 2>/dev/null | column -t || print_ok "All deployments are healthy"

print_subheader "DaemonSets Not Fully Scheduled"
kubectl get daemonsets --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.status.numberReady != .status.desiredNumberScheduled) | "\(.metadata.namespace)\t\(.metadata.name)\t\(.status.numberReady)/\(.status.desiredNumberScheduled)"' 2>/dev/null | column -t || print_ok "All daemonsets are healthy"

print_subheader "StatefulSets Not Fully Ready"
kubectl get statefulsets --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.status.readyReplicas != .status.replicas or .status.readyReplicas == null) | "\(.metadata.namespace)\t\(.metadata.name)\t\(.status.readyReplicas // 0)/\(.status.replicas // 0)"' 2>/dev/null | column -t || print_ok "All statefulsets are healthy"

# ============================================================================
# SERVICES
# ============================================================================
print_header "SERVICES"

print_subheader "Services without Endpoints"
for svc in $(kubectl get svc --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" "}{end}' 2>/dev/null); do
    ns=$(echo "$svc" | cut -d'/' -f1)
    name=$(echo "$svc" | cut -d'/' -f2)
    endpoints=$(kubectl get endpoints -n "$ns" "$name" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
    if [ -z "$endpoints" ]; then
        svc_type=$(kubectl get svc -n "$ns" "$name" -o jsonpath='{.spec.type}' 2>/dev/null)
        # Skip headless services and ExternalName services
        if [ "$svc_type" != "ExternalName" ]; then
            print_warning "$ns/$name (Type: $svc_type) - No endpoints"
        fi
    fi
done | head -20 || print_ok "All services have endpoints"

# ============================================================================
# PVC STATUS
# ============================================================================
print_header "PERSISTENT VOLUME CLAIMS"

print_subheader "PVCs Not Bound"
PVC_ISSUES=$(kubectl get pvc --all-namespaces 2>/dev/null | grep -v "Bound" | grep -v "^NAMESPACE" || true)
if [ -n "$PVC_ISSUES" ]; then
    print_warning "PVCs with issues:"
    kubectl get pvc --all-namespaces 2>/dev/null | head -1
    echo "$PVC_ISSUES"
else
    print_ok "All PVCs are bound"
fi

print_subheader "PV Status"
kubectl get pv 2>/dev/null | head -20 || print_info "No PVs found or no permissions"

# ============================================================================
# RECENT EVENTS - WARNINGS/ERRORS
# ============================================================================
print_header "RECENT CLUSTER EVENTS (Warnings)"

# Helper function to trim whitespace without xargs (handles quotes safely)
trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

print_subheader "Warning Events (last 1 hour)"
WARNING_EVENTS=$(kubectl get events --all-namespaces --field-selector type=Warning -o json 2>/dev/null | jq -r '
    .items 
    | sort_by(.lastTimestamp) 
    | reverse 
    | .[:30] 
    | .[] 
    | "\(.lastTimestamp | split("T")[1] | split(".")[0]) | \(.metadata.namespace | .[0:18]) | \((.involvedObject.kind + "/" + .involvedObject.name) | .[0:45]) | \(.reason | .[0:18]) | \(.message | gsub("[\"'\'']"; "") | .[0:60])"
' 2>/dev/null || true)

if [ -n "$WARNING_EVENTS" ]; then
    printf "${YELLOW}%-10s${NC} | ${CYAN}%-18s${NC} | ${BOLD}%-45s${NC} | %-18s | %s\n" "TIME" "NAMESPACE" "OBJECT" "REASON" "MESSAGE"
    echo "$SUBSEC_SEP"
    echo "$WARNING_EVENTS" | while IFS='|' read -r time ns obj reason msg; do
        printf "%-10s | %-18s | %-45s | ${RED}%-18s${NC} | %s\n" "$(trim "$time")" "$(trim "$ns")" "$(trim "$obj")" "$(trim "$reason")" "$(trim "$msg")"
    done
else
    print_ok "No warning events found"
fi

print_subheader "Failed Events"
FAILED_EVENTS=$(kubectl get events --all-namespaces --field-selector reason=Failed -o json 2>/dev/null | jq -r '
    .items 
    | sort_by(.lastTimestamp) 
    | reverse 
    | .[:15] 
    | .[] 
    | "\(.lastTimestamp | split("T")[1] | split(".")[0]) | \(.metadata.namespace | .[0:18]) | \((.involvedObject.kind + "/" + .involvedObject.name) | .[0:45]) | \(.message | gsub("[\"'\'']"; "") | .[0:50])"
' 2>/dev/null || true)

if [ -n "$FAILED_EVENTS" ]; then
    printf "${YELLOW}%-10s${NC} | ${CYAN}%-18s${NC} | ${BOLD}%-45s${NC} | %s\n" "TIME" "NAMESPACE" "OBJECT" "MESSAGE"
    echo "$SUBSEC_SEP"
    echo "$FAILED_EVENTS" | while IFS='|' read -r time ns obj msg; do
        printf "%-10s | %-18s | %-45s | ${RED}%s${NC}\n" "$(trim "$time")" "$(trim "$ns")" "$(trim "$obj")" "$(trim "$msg")"
    done
else
    print_ok "No failed events"
fi

print_subheader "FailedScheduling Events"
SCHED_EVENTS=$(kubectl get events --all-namespaces --field-selector reason=FailedScheduling -o json 2>/dev/null | jq -r '
    .items 
    | sort_by(.lastTimestamp) 
    | reverse 
    | .[:10] 
    | .[] 
    | "\((.metadata.namespace + "/" + .involvedObject.name) | .[0:50]) | \(.message | gsub("[\"'\'']"; "") | .[0:80])"
' 2>/dev/null || true)

if [ -n "$SCHED_EVENTS" ]; then
    printf "${CYAN}%-50s${NC} | %s\n" "POD" "REASON"
    echo "$SUBSEC_SEP"
    echo "$SCHED_EVENTS" | while IFS='|' read -r pod msg; do
        printf "%-50s | ${RED}%s${NC}\n" "$(trim "$pod")" "$(trim "$msg")"
    done
else
    print_ok "No scheduling failures"
fi

# ============================================================================
# NAMESPACE OVERVIEW
# ============================================================================
print_header "NAMESPACE OVERVIEW"

print_subheader "Pod Count per Namespace"
kubectl get pods --all-namespaces --no-headers 2>/dev/null | awk '{ns[$1]++} END {for (n in ns) print n, ns[n]}' | sort -k2 -rn | column -t

print_subheader "Namespaces with Terminating Pods"
TERMINATING=$(kubectl get pods --all-namespaces 2>/dev/null | grep "Terminating" || true)
if [ -n "$TERMINATING" ]; then
    print_warning "Terminating pods found:"
    echo "$TERMINATING"
else
    print_ok "No stuck terminating pods"
fi

# ============================================================================
# COMPONENT STATUS
# ============================================================================
print_header "CLUSTER COMPONENTS"

print_subheader "Control Plane Components"
kubectl get componentstatuses 2>/dev/null || kubectl get pods -n kube-system -l tier=control-plane 2>/dev/null || print_info "Component status not available"

print_subheader "kube-system Pods"
kubectl get pods -n kube-system -o wide 2>/dev/null | head -30

# ============================================================================
# INGRESS
# ============================================================================
print_header "INGRESS"

print_subheader "All Ingresses"
kubectl get ingress --all-namespaces 2>/dev/null || print_info "No ingresses or permissions"

# ============================================================================
# CERTIFICATES (if cert-manager is installed)
# ============================================================================
print_header "CERTIFICATES (cert-manager)"

if kubectl api-resources | grep -q certificates.cert-manager.io 2>/dev/null; then
    print_subheader "Certificate Status"
    kubectl get certificates --all-namespaces 2>/dev/null || true
    
    print_subheader "Certificates Not Ready"
    kubectl get certificates --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.status.conditions[]?.status != "True") | "\(.metadata.namespace)\t\(.metadata.name)\t\(.status.conditions[0].message)"' 2>/dev/null || print_ok "All certificates ready"
else
    print_info "cert-manager not installed"
fi

# ============================================================================
# NETWORK POLICIES
# ============================================================================
print_header "NETWORK POLICIES"

NP_COUNT=$(kubectl get networkpolicies --all-namespaces --no-headers 2>/dev/null | wc -l)
print_info "Total Network Policies: $NP_COUNT"

if [ "$NP_COUNT" -gt 0 ]; then
    kubectl get networkpolicies --all-namespaces 2>/dev/null | head -20
fi

# ============================================================================
# RESOURCE QUOTAS
# ============================================================================
print_header "RESOURCE QUOTAS"

print_subheader "Resource Quotas (usage)"
kubectl describe resourcequotas --all-namespaces 2>/dev/null | grep -A 10 "^Name:" | head -50 || print_info "No resource quotas configured"

# ============================================================================
# SUMMARY
# ============================================================================
print_header "QUICK SUMMARY"

TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo "0")
TOTAL_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
RUNNING_PODS=$(kubectl get pods --all-namespaces --no-headers --field-selector=status.phase=Running 2>/dev/null | wc -l | tr -d ' ')
PENDING_PODS_COUNT=$(kubectl get pods --all-namespaces --no-headers --field-selector=status.phase=Pending 2>/dev/null | wc -l | tr -d ' ')
FAILED_PODS=$(kubectl get pods --all-namespaces --no-headers --field-selector=status.phase=Failed 2>/dev/null | wc -l | tr -d ' ')

echo -e "
${BOLD}Cluster Summary:${NC}
────────────────────────────────────────
  Nodes:    ${GREEN}${READY_NODES}${NC}/${TOTAL_NODES} Ready
  Pods:     ${GREEN}${RUNNING_PODS}${NC}/${TOTAL_PODS} Running
  Pending:  ${YELLOW}${PENDING_PODS_COUNT}${NC}
  Failed:   ${RED}${FAILED_PODS}${NC}
────────────────────────────────────────
"

if [ "$READY_NODES" -eq "$TOTAL_NODES" ] && [ "$FAILED_PODS" -eq "0" ] && [ "$PENDING_PODS_COUNT" -eq "0" ]; then
    print_ok "Cluster appears healthy!"
else
    print_warning "Cluster has issues that need attention"
fi

echo -e "\n${CYAN}Report generated at: $(date)${NC}\n"
