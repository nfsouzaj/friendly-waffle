#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <image_reference> <newer_than_date (YYYY-MM-DD)>"
    echo "Example: $0 busybox 2023-03-02"
    echo "Example: $0 icr.io/ibm-messaging/mq 2023-03-02"
    exit 1
fi

IMAGE_REF="$1"
NEWER_THAN="$2"

# Convert the newer_than date to seconds since epoch
NEWER_TS=$(date -d "$NEWER_THAN" +%s)

# Prepend docker:// automatically
IMAGE="docker://${IMAGE_REF}"

# Get tags and sort descending
tags=$(skopeo list-tags "$IMAGE" | jq -r '.Tags[]' | sort -Vr)

# Header
printf "%-40s %-25s\n" "TAG" "CREATED"
printf "%-40s %-25s\n" "----------------------------------------" "-------------------------"

for tag in $tags; do
    # Skip tags that look like architecture-specific (e.g., -amd64, -ppc64le, -s390x)
    if [[ "$tag" =~ -(amd64|ppc64le|s390x)$ ]]; then
        continue
    fi

    created=$(skopeo inspect "${IMAGE}:${tag}" 2>/dev/null | jq -r '.Created // empty')
    if [[ -n "$created" ]]; then
        # Convert created timestamp to epoch seconds
        created_ts=$(date -d "$created" +%s)
        if (( created_ts > NEWER_TS )); then
            printf "%-40s %-25s\n" "$tag" "$created"
        fi
    fi
done