# homelab-toolbox: every CLI the lab needs, pinned, in one image.
# Used three ways: on your PC (lab.ps1 / lab.sh), as a Jenkins agent pod on K3s,
# and in GitHub Actions. Same versions everywhere.
FROM python:3.13-slim-trixie

# Bump these deliberately (Renovate can do it later). A wrong version fails the build loudly.
ARG TERRAFORM_VERSION=1.15.3
ARG KUBECTL_VERSION=v1.36.5
ARG FLUX_VERSION=2.8.8
ARG SOPS_VERSION=3.13.0
ARG ANSIBLE_CORE="ansible-core>=2.20,<2.22"

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    ANSIBLE_FORCE_COLOR=1 \
    TF_IN_AUTOMATION=0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openssh-client git curl ca-certificates unzip jq age iputils-ping dnsutils less nano \
 && rm -rf /var/lib/apt/lists/*

# Terraform, verified against HashiCorp's published checksums
RUN set -eu; cd /tmp; \
    curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"; \
    curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS"; \
    grep "linux_amd64.zip" "terraform_${TERRAFORM_VERSION}_SHA256SUMS" | sha256sum -c -; \
    unzip -q "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -d /usr/local/bin; \
    rm -f terraform_*; terraform version

# kubectl, verified against the upstream .sha256
RUN set -eu; cd /usr/local/bin; \
    curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
    echo "$(curl -fsSL https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256)  kubectl" | sha256sum -c -; \
    chmod +x kubectl; kubectl version --client

# Flux CLI, verified against the release checksums
RUN set -eu; cd /tmp; \
    curl -fsSLO "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_amd64.tar.gz"; \
    curl -fsSLO "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_checksums.txt"; \
    grep "linux_amd64.tar.gz" "flux_${FLUX_VERSION}_checksums.txt" | sha256sum -c -; \
    tar -xzf "flux_${FLUX_VERSION}_linux_amd64.tar.gz" -C /usr/local/bin flux; \
    rm -f flux_*; flux --version

# SOPS, verified against the release checksums
RUN set -eu; cd /tmp; \
    curl -fsSLO "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64"; \
    curl -fsSLO "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.checksums.txt"; \
    grep " sops-v${SOPS_VERSION}.linux.amd64$" "sops-v${SOPS_VERSION}.checksums.txt" | sha256sum -c -; \
    install -m 0755 "sops-v${SOPS_VERSION}.linux.amd64" /usr/local/bin/sops; \
    rm -f sops-*; sops --version

# Ansible + the collections homelab-ansible uses + WinRM for dc-01 + linters
RUN pip install "${ANSIBLE_CORE}" pywinrm ansible-lint yamllint \
 && ansible-galaxy collection install -p /usr/share/ansible/collections \
      "ansible.posix:>=2.0.0,<3.0.0" \
      "community.general:>=11.0.0,<14.0.0" \
      "ansible.windows:>=3.0.0,<4.0.0" \
      "microsoft.ad:>=1.8.0,<2.0.0" \
 && ansible --version

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
