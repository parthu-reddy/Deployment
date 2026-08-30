#!/usr/bin/env bash
#
# Deploy one or more services to the VM. Pulls a tagged image and brings the container up.
#
#   Deployment/deploy.sh customer-service [more-services...]
#
# It does NOT build, rsync source, or run Maven. Images come from the registry, tagged by
# publish.sh. See RandomDocuments/DeploymentRedesign_2026-08-29/Phase2_SingleDeployPath.
#
# It verifies the container ends up on the INTENDED image. On 2026-08-30 the old script exited 0
# having shipped nothing: the container stayed up 51 minutes on the previous image, reporting
# healthy the whole time. Healthy answers "is something running", never "is what I built running".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="$ROOT/Deployment/service-map.tsv"
VERSIONS="$ROOT/Deployment/.versions"
LOG="$ROOT/Deployment/DEPLOY_LOG.md"
SSH_KEY="${SSH_KEY:-/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key}"
VM="${VM:-ubuntu@140.245.234.137}"
REMOTE="Food Delivery.nosync/Deployment"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-180}"

die() { echo "deploy: $*" >&2; exit 1; }
remote() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" "$@" </dev/null; }

[[ -f "$MAP" ]] || die "missing $MAP"
[[ -f "$VERSIONS" ]] || die "missing $VERSIONS -- publish an image first"
[[ -n "${REGISTRY:-}" ]] || die "REGISTRY is not set"
[[ $# -gt 0 ]] || die "usage: deploy.sh <compose-service>..."

valid() { awk -F'\t' '!/^#/ && NF>=2 {print $2}' "$MAP"; }

# Resolve everything locally before touching the VM: a typo must cost a second, not a failed
# half-deploy. This retires the 7 stale service names the old per-service scripts carried.
declare -a SERVICES=() IMAGES=()
for svc in "$@"; do
    valid | grep -qx "$svc" || die "unknown service '$svc'
valid services:
$(valid | sed 's/^/  /')"
    var="$(echo "$svc" | tr 'a-z-' 'A-Z_')_TAG"
    tag="$(awk -F= -v v="$var" '$1==v {print $2}' "$VERSIONS")"
    [[ -n "$tag" ]] || die "no tag recorded for $svc -- run: Deployment/publish.sh $svc"
    SERVICES+=("$svc")
    IMAGES+=("$REGISTRY/food-delivery/$svc:$tag")
done

echo "==> deploying ${#SERVICES[@]} service(s) to $VM"
for i in "${!SERVICES[@]}"; do echo "    ${SERVICES[$i]} -> ${IMAGES[$i]}"; done

before="$(remote "cd '$REMOTE' && for s in ${SERVICES[*]}; do printf '%s=%s\n' \"\$s\" \"\$(docker inspect -f '{{.Config.Image}}' \$s 2>/dev/null || echo none)\"; done")"

# compose interpolates ${REGISTRY} and ${<SVC>_TAG} from the shell it runs in, and .versions lives
# on this machine -- so the values are passed explicitly rather than assumed present on the VM.
# EVERY tag, not just the ones being deployed. `docker compose up -d <one-service>` still parses
# the whole file, so an unset ${X_TAG} for any other service resolves to a blank string and
# compose fails with "invalid reference format" on an image that was never being touched.
ENVS="REGISTRY=$REGISTRY"
while IFS= read -r line; do
    case "$line" in ''|\#*) continue;; esac
    ENVS="$ENVS $line"
done < "$VERSIONS"

# The deployed services use the tag resolved above, which is the same value unless .versions
# changed under us mid-run; re-stating them makes the intent explicit rather than implicit.
for i in "${!SERVICES[@]}"; do
    ENVS="$ENVS $(echo "${SERVICES[$i]}" | tr 'a-z-' 'A-Z_')_TAG=${IMAGES[$i]##*:}"
done

# One round trip. --remove-orphans so undeclared containers cannot accumulate silently.
remote "cd '$REMOTE' && env $ENVS docker compose pull ${SERVICES[*]} && env $ENVS docker compose up -d --remove-orphans ${SERVICES[*]}"

echo "==> waiting for health (timeout ${HEALTH_TIMEOUT}s)"
remote "cd '$REMOTE' && end=\$((SECONDS+$HEALTH_TIMEOUT)); while [ \$SECONDS -lt \$end ]; do
  bad=0
  for s in ${SERVICES[*]}; do
    st=\$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \$s 2>/dev/null || echo missing)
    case \"\$st\" in healthy|running) ;; *) bad=1 ;; esac
  done
  [ \$bad -eq 0 ] && exit 0
  sleep 5
done; echo 'TIMEOUT waiting for health'; exit 1"

after="$(remote "cd '$REMOTE' && for s in ${SERVICES[*]}; do printf '%s=%s\n' \"\$s\" \"\$(docker inspect -f '{{.Config.Image}}' \$s 2>/dev/null || echo none)\"; done")"

# The check the old script lacked: is the container on the image we intended?
fail=0
for i in "${!SERVICES[@]}"; do
    svc="${SERVICES[$i]}"; want="${IMAGES[$i]}"
    got="$(echo "$after" | awk -F= -v s="$svc" '$1==s {print $2}')"
    was="$(echo "$before" | awk -F= -v s="$svc" '$1==s {print $2}')"
    if [[ "$got" != "$want" ]]; then
        echo "deploy: $svc is running '$got' but should be '$want' (was '$was')" >&2
        fail=1
    else
        echo "    OK  $svc -> $got"
    fi
done
[[ $fail -eq 0 ]] || die "one or more services are not on the intended image"

{
    printf '| %s | %s | %s | %s |\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${SERVICES[*]}" \
        "$(for i in "${!SERVICES[@]}"; do echo -n "${IMAGES[$i]##*:} "; done)" \
        "$(git config user.email 2>/dev/null || whoami)"
} >> "$LOG"

for s in "${SERVICES[@]}"; do
    [[ "$s" == "food-delivery-app-ui" ]] && echo "NOTE: hard-refresh the browser (Cmd+Shift+R) -- Vite bundles are cached client-side."
done
echo "==> done"
