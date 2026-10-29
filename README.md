# homelab-toolbox

One container image with every CLI lab-zrh-pve-01 needs, at pinned versions:
Terraform, Ansible (+ collections, pywinrm, ansible-lint), kubectl, Flux, SOPS, age.

| Where | How |
|---|---|
| Your PC (Windows) | `lab.ps1` via Podman Desktop or Docker Desktop |
| Your PC (Linux/WSL) | `lab.sh` |
| K3s (Phase 9+) | Jenkins agent pod, image pinned to `:<sha>` |
| GitHub Actions | `container: ghcr.io/lootregenit/homelab-toolbox:<sha>` |

## Why not run Terraform and Ansible *only* inside the cluster

Terraform creates the K3s VMs, and Ansible installs K3s. If they only lived in K3s,
a broken cluster would take away the tools to repair it, and an apply that replaces
a K3s node would kill its own runner halfway. So:

- **Bootstrap and break-glass:** this image on your PC. Builds everything from nothing.
- **Day 2 (Phase 9+):** the same image as a Jenkins pod on K3s: `terraform plan` on every
  push, `apply` after you approve, a nightly `ansible-playbook --check` that reports drift.
- **State** is in HCP Terraform, so both paths see the same state and its lock.

## First use (Windows)

```powershell
# repos side by side in %USERPROFILE%\homelab\  (homelab, homelab-ansible, homelab-terraform, ...)
git config --global core.autocrlf false        # before cloning! see .gitattributes
. $env:USERPROFILE\homelab\homelab-toolbox\lab.ps1

podman pull ghcr.io/lootregenit/homelab-toolbox:main      # or: docker pull
lab homelab-ansible ansible --version
```

Put `. $env:USERPROFILE\homelab\homelab-toolbox\lab.ps1` into `$PROFILE` to have `lab` in every window.

State that must survive between runs lives in `%USERPROFILE%\.lab\`:
`terraform.d` (HCP login), `kube` (kubeconfig), `ansible` (`vault_pass`, `secrets/`).
Put the vault password at `%USERPROFILE%\.lab\ansible\vault_pass`.

## Line endings

Bash scripts and Jinja templates break with Windows line endings. Every repo has a
`.gitattributes` with `* text=auto eol=lf`, and `core.autocrlf false` keeps Git
from converting them on Windows.
