#!/bin/bash

echo "=== Pods where REQUEST > CURRENT USAGE (CPU or Memory) ==="
echo -e "NAMESPACE\tPOD\tCPU_REQ(m)\tCPU_USED(m)\tMEM_REQ(Mi)\tMEM_USED(Mi)"

kubectl get pods -A -o json | jq -cr '
  .items[]
  # Exclude kube-* namespaces and gatekeeper-system only
  | select(
      (.metadata.namespace | startswith("kube-") | not)
      and
      (.metadata.namespace != "gatekeeper-system")
    )
  | select(.spec.containers[].resources.requests?)
  | {
      ns: .metadata.namespace,
      pod: .metadata.name,
      cpu_req: (
        [.spec.containers[].resources.requests.cpu // "0"]
        | map(
            if endswith("m") then sub("m";"") | tonumber
            else (tonumber * 1000)
            end
          )
        | add
      ),
      mem_req: (
        [.spec.containers[].resources.requests.memory // "0"]
        | map(
            if endswith("Mi") then sub("Mi";"") | tonumber
            elif endswith("Gi") then (sub("Gi";"") | tonumber) * 1024
            else 0
            end
          )
        | add
      )
    }
' | while IFS= read -r line; do

  ns=$(jq -r '.ns' <<< "$line")
  name=$(jq -r '.pod' <<< "$line")
  cpu_req=$(jq -r '.cpu_req' <<< "$line")
  mem_req=$(jq -r '.mem_req' <<< "$line")

  usage=$(kubectl top pod "$name" -n "$ns" --no-headers 2>/dev/null)
  [[ -z "$usage" ]] && continue

  cpu_used=$(awk '{print $2}' <<< "$usage" | sed 's/m//')
  mem_used=$(awk '{print $3}' <<< "$usage" | sed 's/Mi//')

  if [[ $cpu_req -gt $cpu_used || $mem_req -gt $mem_used ]]; then
    echo -e "$ns\t$name\t$cpu_req\t$cpu_used\t$mem_req\t$mem_used"
  fi

done | column -t

