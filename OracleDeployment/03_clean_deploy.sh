#!/usr/bin/env bash
#
# Clean, full deployment of every service onto the Oracle VM.
#
#   Deployment/OracleDeployment/03_clean_deploy.sh              deploy everything
#   Deployment/OracleDeployment/03_clean_deploy.sh --wipe       destroy volumes first, then deploy
#
# Runs from the workspace root ON THE MAC, not on the VM. The VM holds no source code and does not
# build anything: images are built here (or by CI), pushed to OCIR, and pulled by the VM. The three
# scripts this replaces -- 03_deploy_all.sh, 03_deploy_dev.sh, 04_clean_deploy_one_by_one.sh -- all
# ran `mvn clean package` and `docker compose build` on the VM. None of them can work any more; the
# VM's copy of the workspace contains only `Deployment/`.
#
# Publish first if the images are not in the registry yet:
#     Deployment/publish.sh                 # all services
#     Deployment/publish.sh customer-service
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/Deployment"
VERSIONS="$DEPLOY/.versions"
SSH_KEY="${SSH_KEY:-/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key}"
VM="${VM:-ubuntu@140.245.234.137}"
REMOTE="Food Delivery.nosync/Deployment"
WIPE=false
[[ "${1:-}" == "--wipe" ]] && WIPE=true

die() { echo "clean-deploy: $*" >&2; exit 1; }
remote() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" "$@" </dev/null; }

[[ -n "${REGISTRY:-}" ]] || die "REGISTRY is not set. export REGISTRY=hyd.ocir.io/<namespace>"
[[ -f "$VERSIONS" ]] || die "missing $VERSIONS -- run Deployment/publish.sh first"

# Infrastructure and third-party images. These are NOT built or published by us: postgres, redis,
# kafka, zookeeper, clickhouse and jaeger are upstream images, and api-docs is plain nginx:alpine.
# That is why .versions carries 20 tags while compose declares 27 services.
INFRA="zookeeper kafka postgres redis clickhouse jaeger api-docs"

# Ordered waves. Everything at once put 27 JVMs on a 4-core box and drove load average past 120;
# config and discovery also have to be answering before anything else asks them for configuration.
WAVE1="config-service eureka-server-1 eureka-server-2"

APP="$(awk -F= '/_TAG=/{print $1}' "$VERSIONS" \
      | sed 's/_TAG$//' | tr 'A-Z_' 'a-z-' | sort)"
WAVE2="$(echo "$APP" | grep -vxE "$(echo $WAVE1 | tr ' ' '|')" | tr '\n' ' ')"

echo "=========================================================="
echo " Clean deployment -> $VM"
echo " registry : $REGISTRY"
echo " wave 1   : $WAVE1"
echo " wave 2   : $(echo $WAVE2 | wc -w | tr -d ' ') services"
echo " wipe     : $WIPE"
echo "=========================================================="

if [[ "$WIPE" == true ]]; then
    echo
    echo "!! --wipe destroys every container AND every volume on $VM."
    echo "!! All database contents are lost. Dummy data must be recreated afterwards:"
    echo "!!   Deployment/OracleDeployment/DummyData/reset_remote_db.sh"
    read -r -p "Type WIPE to continue: " confirm
    [[ "$confirm" == "WIPE" ]] || die "aborted"
    echo "==> tearing down containers and volumes"
    remote "cd '$REMOTE' && docker compose down -v --remove-orphans"
fi

# Secrets and image tags. .env holds the credentials; without REGISTRY and the *_TAG values written
# alongside them the VM cannot resolve its own image names, and every compose command run there by
# hand operates on a different world than the one running.
if [[ -n "${OCI_VAULT_ID:-}" ]]; then
    echo "==> fetching secrets from vault into the VM's .env"
    remote "export OCI_VAULT_ID=\"$OCI_VAULT_ID\" && cd '$REMOTE/OracleDeployment' && ./fetch_secrets_from_vault.sh"
else
    echo "==> skipping vault fetch (OCI_VAULT_ID not set); relying on existing secrets"
fi

echo "==> syncing REGISTRY and image tags into the VM's .env"
"$DEPLOY/deploy.sh" --sync-env

echo "==> starting infrastructure: $INFRA"
remote "cd '$REMOTE' && docker compose up -d $INFRA"

echo "==> waiting for postgres to accept connections"
remote "cd '$REMOTE' && for i in \$(seq 1 30); do
    docker compose exec -T postgres pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1 && { echo '    postgres ready'; exit 0; }
    sleep 5
done; echo 'postgres did not become ready'; exit 1"

# deploy.sh pulls, starts, waits for health, and then verifies each container actually ended up on
# the image it was told to run -- the check that makes a silent no-op deploy impossible.
echo "==> wave 1: configuration and discovery"
"$DEPLOY/deploy.sh" $WAVE1

echo "==> wave 2: application services"
"$DEPLOY/deploy.sh" $WAVE2

echo "==> reconciling declared against running"
"$DEPLOY/reconcile.sh"

echo "=========================================================="
echo " Deployment complete."
echo " UI:    http://${VM##*@}"
echo " Logs:  ssh -i \$SSH_KEY $VM \"cd '$REMOTE' && docker compose logs -f <service>\""
echo "=========================================================="
