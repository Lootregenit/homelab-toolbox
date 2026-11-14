# homelab-toolbox

One container image with every CLI lab-zrh-pve-01 needs, at pinned versions:
Terraform, Ansible (+ collections, pywinrm, ansible-lint), kubectl, Flux, SOPS, age.

| Where | How |
|---|---|
| Your PC (Windows) | `lab.ps1` via Podman Desktop or Docker Desktop |
| Your PC (Linux/WSL) | `lab.sh` |
| K3s (Phase 10) | Azure Pipelines agent: `homelab-azp-agent:<sha>` = this image + the agent (`Containerfile.agent`) |
| GitHub Actions | `container: ghcr.io/lootregenit/homelab-toolbox:<sha>` |

## Why not run Terraform and Ansible *only* inside the cluster

Terraform creates the K3s VMs, and Ansible installs K3s. If they only lived in K3s,
a broken cluster would take away the tools to repair it, and an apply that replaces
a K3s node would kill its own runner halfway. So:

- **Bootstrap and break-glass:** this image on your PC. Builds everything from nothing.
- **Day 2 (Phase 10):** the same image as an Azure Pipelines agent on K3s: `terraform plan` on
  every pull request, `apply` after you approve, `ansible-playbook --check --diff` before every run.
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

## The agent image

`Containerfile.agent` adds the Azure Pipelines agent to the toolbox and runs it as user
`agent` (uid 1000). `agent/start.sh` registers the agent with a PAT, removes the PAT from
the environment and starts the agent with `--once`: one job per container, then Kubernetes
starts a clean one. The agent does not update itself; a new version is a commit here
(`AZP_AGENT_VERSION` and `AZP_AGENT_SHA256`).

Each build on `main` pushes `ghcr.io/lootregenit/homelab-azp-agent:<12-char sha>`.
Put that tag into the cluster with `bash scripts/set-image-tag.sh apps/azp-agents <sha>` in `homelab`.
