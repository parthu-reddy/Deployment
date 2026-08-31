#!/usr/bin/env bash
#
# Compare what docker-compose.yml DECLARES against what is RUNNING on the VM.
#
#   Deployment/reconcile.sh            report only
#   Deployment/reconcile.sh --apply    additionally stop and remove undeclared containers
#
# Reports before removing, deliberately. "Undeclared" can mean "leftover from an older revision"
# or "someone forgot to declare it", and nothing here can tell the two apart. On 2026-08-31
# deploy.sh's --remove-orphans deleted reviews-service, which was wanted -- removal without a
# decision is exactly what this exists to avoid.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE="$ROOT/Deployment/docker-compose.yml"
SSH_KEY="${SSH_KEY:-/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key}"
VM="${VM:-ubuntu@140.245.234.137}"
REMOTE="Food Delivery.nosync/Deployment"
APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

die() { echo "reconcile: $*" >&2; exit 1; }
remote() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" "$@" </dev/null; }

[[ -f "$COMPOSE" ]] || die "missing $COMPOSE"

# Declared: service keys, with commented-out blocks stripped so a '#  foo:' line is not counted.
declared="$(grep -vE '^\s*#' "$COMPOSE" | grep -oE '^  [a-z0-9_-]+:$' | tr -d ' :' | sort)"
# docker compose ps reports the SERVICE name; docker ps reports the CONTAINER name, and they
# differ for infrastructure (service `postgres` runs as container `shared_postgres`). Comparing the
# two namespaces made six infra services look simultaneously missing and undeclared.
running="$(remote "cd '$REMOTE' && docker compose ps -a --format '{{.Service}}'" 2>/dev/null | grep -vE '^\s*$' | sort -u)"
# Containers compose does not know about at all -- true orphans from an older revision -- have no
# compose service name, so they are picked up separately by container name.
orphans="$(remote "cd '$REMOTE' && comm -13 <(docker compose ps -a --format '{{.Name}}' | sort -u) <(docker ps -a --format '{{.Names}}' | sort -u)" 2>/dev/null | grep -vE '^\s*$' || true)"

both="$(comm -12 <(echo "$declared") <(echo "$running"))"
missing="$(comm -23 <(echo "$declared") <(echo "$running"))"
extra="$(printf '%s\n%s\n' "$(comm -13 <(echo "$declared") <(echo "$running"))" "$orphans" | grep -vE '^\s*$' | sort -u || true)"

printf '  declared and running : %s\n' "$(echo "$both"    | grep -c . || true)"
printf '  declared, NOT running: %s\n' "$(echo "$missing" | grep -c . || true)"
printf '  running, NOT declared: %s\n' "$(echo "$extra"   | grep -c . || true)"

[[ -n "$missing" ]] && { echo; echo "  declared but not running:"; echo "$missing" | sed 's/^/    /'; }
[[ -n "$extra"   ]] && { echo; echo "  running but not declared:"; echo "$extra"   | sed 's/^/    /'; }

# Existing-and-declared is not the same as correct. A container can be running an image the compose
# file no longer declares -- someone ran `docker run`, a deploy half-failed, or .env drifted. Compare
# the declared image against the running one, resolving the CONTAINER name through compose: service
# `postgres` runs as container `shared_postgres`, and inspecting by service name reports every
# infrastructure container as missing.
echo
echo "  image drift (declared vs running):"
remote "cd '$REMOTE' && docker compose config --format json 2>/dev/null > /tmp/cfg.json && \
 docker compose ps -a --format '{{.Service}}\t{{.Name}}' 2>/dev/null > /tmp/names.tsv && \
 python3 - <<'EOF'
import json,subprocess
cfg=json.load(open('/tmp/cfg.json'))['services']
names=dict(l.split('\t') for l in open('/tmp/names.tsv').read().splitlines() if '\t' in l)
drift=[]
for svc,spec in sorted(cfg.items()):
    want=spec.get('image','')
    cname=names.get(svc)
    if not cname:
        drift.append((svc,want,'NOT RUNNING')); continue
    got=subprocess.run(['docker','inspect','-f','{{.Config.Image}}',cname],
                       capture_output=True,text=True).stdout.strip()
    if want!=got: drift.append((svc,want,got))
for s,w,g in drift: print('    DRIFT %-26s declared=%s running=%s'%(s,w,g))
print('    %d services checked, %d drifting'%(len(cfg),len(drift)))
EOF"

if [[ -z "$extra" ]]; then
    echo; echo "  no undeclared containers to reconcile."
    exit 0
fi

if [[ "$APPLY" != true ]]; then
    echo
    echo "  Report only. Decide whether each is a leftover or a missing declaration."
    echo "  To remove them:  Deployment/reconcile.sh --apply"
    exit 0
fi

echo
echo "==> removing undeclared containers"
while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    echo "    removing $c"
    remote "docker rm -f '$c' >/dev/null 2>&1 || true"
done <<< "$extra"
echo "==> done"
