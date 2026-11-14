#!/usr/bin/env bash
# Registers this container as an Azure Pipelines agent, then runs it.
#
#   AZP_URL         https://dev.azure.com/<organization>
#   AZP_POOL        agent pool name
#   AZP_TOKEN       PAT with only "Agent Pools (Read & manage)", from a Kubernetes Secret
#   AZP_AGENT_NAME  optional; default is the hostname
#
# Arguments go to run.sh. With --once (the image's default) the agent takes one job
# and exits; Kubernetes restarts the container, so every job starts from the clean image.
set -euo pipefail

: "${AZP_URL:?missing AZP_URL}"
: "${AZP_POOL:?missing AZP_POOL}"
: "${AZP_TOKEN:?missing AZP_TOKEN}"

# The agent publishes its environment as "capabilities". Never the token.
export VSO_AGENT_IGNORE="AZP_TOKEN,VSTS_AGENT_INPUT_TOKEN"

cd /azp/agent

# The token goes in through the environment, so it never shows up in the process list.
# --replace: a restarted container takes over the registration with the same name.
# --disableupdate: the agent version is the one in the image, changed by a commit.
VSTS_AGENT_INPUT_TOKEN="$AZP_TOKEN" ./config.sh --unattended \
  --agent "${AZP_AGENT_NAME:-$(hostname)}" \
  --url "$AZP_URL" \
  --auth PAT \
  --pool "$AZP_POOL" \
  --work _work \
  --replace \
  --acceptTeeEula \
  --disableupdate

# The PAT was only needed to register. Jobs must not see it: after this exec it is
# gone from the environment of every process in the container.
unset AZP_TOKEN
exec ./run.sh "$@"
