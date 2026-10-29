#!/usr/bin/env bash
# Linux/WSL version of lab.ps1:  ./lab.sh homelab-ansible ansible-playbook playbooks/proxmox.yml
set -euo pipefail

LAB_REPOS="${LAB_REPOS:-$HOME/homelab}"
LAB_STATE="${LAB_STATE:-$HOME/.lab}"
LAB_IMAGE="${LAB_IMAGE:-ghcr.io/lootregenit/homelab-toolbox:main}"
ENGINE="$(command -v podman || command -v docker)"

repo="${1:?usage: lab.sh <repo> [command...]}"; shift
[ -d "$LAB_REPOS/$repo" ] || { echo "No repo '$repo' in $LAB_REPOS" >&2; exit 1; }
mkdir -p "$LAB_STATE"/{terraform.d,kube,ansible}
[ $# -gt 0 ] || set -- bash

env_args=()
for v in PROXMOX_VE_ENDPOINT PROXMOX_VE_API_TOKEN TF_CLOUD_ORGANIZATION GITHUB_TOKEN KUBECONFIG; do
  [ -n "${!v:-}" ] && env_args+=(-e "$v")
done
# Reuse the host's ssh-agent when there is one
if [ -n "${SSH_AUTH_SOCK:-}" ]; then
  env_args+=(-v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent)
fi

exec "$ENGINE" run --rm -it \
  -v "$LAB_REPOS:/work" \
  -v "$HOME/.ssh:/mnt/ssh:ro" \
  -v "$LAB_STATE/terraform.d:/root/.terraform.d" \
  -v "$LAB_STATE/kube:/root/.kube" \
  -v "$LAB_STATE/ansible:/root/.ansible" \
  -w "/work/$repo" \
  "${env_args[@]}" \
  "$LAB_IMAGE" "$@"
