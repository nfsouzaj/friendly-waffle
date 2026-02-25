#!/usr/bin/env bash
#
# Homebrew Bulk Upgrade Script
# Upgrades all specified Homebrew formulae and casks.
#
# Usage: ./brew.sh
#
set -e

# Ensure Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "Homebrew installed. Please restart your terminal or follow any on-screen instructions before re-running this script."
  exit 1
fi

# ----------------------
# Formulae (CLI tools, libraries, dev tools)
# ----------------------
formulae=(
  # Kubernetes & Cloud
  cilium-cli flux@2.2 helm k3d kube-ps1 kubeconform kubelogin kubernetes-cli kustomize kyverno stern
  # Dev Tools
  checkov coreutils cowsay darksky-weather go go-task jq pre-commit shellcheck sl speedtest terraform tflint tmux trivy wget yq
  # Python & Data
  certifi numpy pydantic python@3.11 python@3.13 python@3.14 rpds-py
  # Security
  gnupg gpgme pinentry pwsafe
  # Networking
  ca-certificates openssl@3 unbound
  # Libraries
  libyaml melange mpfr ncurses nettle npth oniguruma openblas oras readline skopeo
  # Misc
  apko git
)

# ----------------------
# Casks (GUI apps, SDKs, VMs)
# ----------------------
casks=(
  gcloud-cli
  google-cloud-sdk
  hashicorp-vagrant
  headlamp
  vagrant
  virtualbox@beta
  virtualbox-beta
)

echo -e "\n--- Upgrading Homebrew formulae ---"
for pkg in "${formulae[@]}"; do
  echo "Upgrading $pkg..."
  brew upgrade "$pkg"
done

echo -e "\n--- Upgrading Homebrew casks ---"
for cask in "${casks[@]}"; do
  echo "Upgrading cask $cask..."
  brew upgrade --cask "$cask"
done

echo -e "\nAll Homebrew packages and casks are up to date!"