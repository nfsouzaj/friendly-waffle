# friendly-waffle

## Why 'friendly-waffle'?

I picked the name 'friendly-waffle' because, honestly, tech projects can feel a bit dry sometimes—and who doesn't love waffles? The idea is to keep things light, approachable, and fun. Just like a good waffle, these tools are meant to be easy to use and share. The 'friendly' part is a reminder that this repo is for everyone working with Kubernetes, whether you're just starting out or deep in the trenches. Let's make things a little tastier together!

## Introduction

This repository is dedicated to creating and collecting useful tools and scripts for Kubernetes environments. The goal is to simplify common tasks, automate workflows, and provide practical utilities for developers and operators working with Kubernetes.

## Scripts

- **k8s-cluster-health.sh**: Comprehensive cluster health check. Shows problematic pods, node status, resource usage, events, and a summary. Run it when you need a quick overview of a cluster's state.

- **po-report-compute-usage.sh**: Reports pods where CPU/memory requests exceed actual usage. Helps identify over-provisioned workloads.

- **tag-and-pushdate.sh**: Lists image tags created after a specified date. Requires `skopeo` and `jq`.

- **brew.sh**: Homebrew bulk upgrade script. Upgrades a curated list of formulae (K8s tools, dev tools, security, etc.) and casks (GUI apps). Installs Homebrew if missing.

More scripts will be added as the repository grows.
