#!/usr/bin/env bash
# Linux/WSL version of lab.ps1:  ./lab.sh homelab-ansible ansible-playbook playbooks/proxmox.yml
set -euo pipefail

LAB_REPOS="${LAB_REPOS:-$HOME/homelab}"
LAB_STATE="${LAB_STATE:-$HOME/.lab}"
LAB_IMAGE="${LAB_IMAGE:-ghcr.io/lootregenit/homelab-toolbox:main}"
LAB_KUBECONFIG="${LAB_KUBECONFIG:-/root/.kube/lab-zrh-pve-01.yaml}"   # path INSIDE the container
ENGINE="$(command -v podman || command -v docker)"

repo="${1:?usage: lab.sh <repo> [command...]}"; shift
[ -d "$LAB_REPOS/$repo" ] || { echo "No repo '$repo' in $LAB_REPOS" >&2; exit 1; }
mkdir -p "$LAB_STATE"/{terraform.d,kube,ansible}
[ $# -gt 0 ] || set -- bash

env_args=()
# Pin lab names: plain DNS answers with private IPs get dropped (DNS rebinding protection)
for h in pve-01.infra.lootregen.com:192.168.1.100 pve-02.infra.lootregen.com:192.168.1.101 pve-03.infra.lootregen.com:192.168.1.102; do
  env_args+=(--add-host "$h")
done
for v in PROXMOX_VE_ENDPOINT PROXMOX_VE_API_TOKEN TF_CLOUD_ORGANIZATION GITHUB_TOKEN; do
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
  -e "KUBECONFIG=$LAB_KUBECONFIG" \
  "${env_args[@]}" \
  "$LAB_IMAGE" "$@"
