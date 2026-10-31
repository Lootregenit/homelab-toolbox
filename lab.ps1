# Runs a command from the homelab-toolbox container in one of the lab repos.
#
#   . .\lab.ps1                                    # load the function (or put it in $PROFILE)
#   lab homelab-ansible ansible-playbook playbooks/proxmox.yml
#   lab homelab-terraform terraform plan
#   lab homelab                                    # interactive shell in that repo
#
# Needs Podman Desktop or Docker Desktop (both run on WSL2).
# PROXMOX_VE_ENDPOINT / PROXMOX_VE_API_TOKEN / TF_CLOUD_ORGANIZATION are passed
# through from this PowerShell session if they are set. Nothing secret is stored.

$LabRepos  = "$env:USERPROFILE\homelab"                      # folder holding the repos side by side
$LabState  = "$env:USERPROFILE\.lab"                         # terraform login token, kubeconfig, ansible secrets
$LabImage  = "ghcr.io/lootregenit/homelab-toolbox:main"
# Lab names the container resolves without DNS. Plain DNS (port 53) answers with
# private IPs get dropped on this network (DNS rebinding protection), so pin them.
$LabHosts  = @{
    "pve-01.infra.lootregen.com" = "192.168.1.100"
    "pve-02.infra.lootregen.com" = "192.168.1.101"
    "pve-03.infra.lootregen.com" = "192.168.1.102"
}
$LabEngine = if (Get-Command podman -ErrorAction SilentlyContinue) { "podman" } else { "docker" }

# A plain function on purpose: $args keeps flags like --check or -auto-approve
# as text instead of PowerShell trying to read them as its own parameters.
function lab {
    if ($args.Count -lt 1) { throw "usage: lab <repo> [command...]" }
    $Repo    = $args[0]
    # @( ) around the whole if: PowerShell unrolls a one-item array to a plain string,
    # and splatting a string passes its characters ("b" "a" "s" "h").
    $Command = @(if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { "bash" })

    if (-not (Test-Path "$LabRepos\$Repo")) { throw "No repo '$Repo' in $LabRepos" }
    foreach ($d in "terraform.d", "kube", "ansible") {
        New-Item -ItemType Directory -Force -Path "$LabState\$d" | Out-Null
    }

    $runArgs = @(
        "run", "--rm", "-it",
        "-v", "${LabRepos}:/work",
        "-v", "$env:USERPROFILE\.ssh:/mnt/ssh:ro",
        "-v", "$LabState\terraform.d:/root/.terraform.d",
        "-v", "$LabState\kube:/root/.kube",
        "-v", "$LabState\ansible:/root/.ansible",
        "-w", "/work/$Repo"
    )
    foreach ($n in $LabHosts.Keys) { $runArgs += @("--add-host", "${n}:$($LabHosts[$n])") }
    foreach ($v in "PROXMOX_VE_ENDPOINT", "PROXMOX_VE_API_TOKEN", "TF_CLOUD_ORGANIZATION", "GITHUB_TOKEN", "KUBECONFIG") {
        if (Test-Path "env:$v") { $runArgs += @("-e", $v) }
    }

    & $LabEngine @runArgs $LabImage @Command
}
