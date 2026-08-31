#!/usr/bin/env bash
#
# Push config YAML to the VM. 
#
#   Deployment/publish-config.sh api-gateway.yml [more-configs...]
#   Deployment/publish-config.sh --all
#   Deployment/publish-config.sh --dry-run [--all | <config.yml>...]
#
# Configs are bind-mounted into config-service on the VM. A config push does not restart
# anything; run `deploy.sh --config <service>` to bounce the readers.
#
# Excluded from shipping (never rsynced regardless of --all):
#   docker-compose.yml, .env, .env.local, node_modules/, __pycache__/, *.log
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_KEY="${SSH_KEY:-/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key}"
VM="${VM:-ubuntu@140.245.234.137}"
# The space is backslash-escaped inside single quotes, because macOS rsync 2.6.9 lacks
# --protect-args and the remote shell will split it otherwise.
# Built from $VM so overriding VM= keeps rsync and the md5 check in sync.
REMOTE_DIR="${VM}:/home/ubuntu/Food\\ Delivery.nosync/Deployment"
REMOTE_PATH_MD5="/home/ubuntu/Food Delivery.nosync/Deployment"

die() { echo "publish-config: $*" >&2; exit 1; }
remote() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" "$@" </dev/null; }

# Never ship these; .env is written on the VM by the vault script, node_modules and __pycache__
# are build artefacts, *.log is transient.
EXCLUDED_NAMES="docker-compose.yml .env .env.local"
EXCLUDED_DIRS="node_modules __pycache__ .npm-cache"

is_excluded() {
    local name="$1"
    for ex in $EXCLUDED_NAMES; do [[ "$name" == "$ex" ]] && return 0; done
    for ex in $EXCLUDED_DIRS; do [[ "$name" == "$ex" ]] && return 0; done
    [[ "$name" == *.log ]] && return 0
    return 1
}

DRY_RUN=false
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true;;
        *) ARGS+=("$arg");;
    esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

if [[ "${1:-}" == "--all" ]]; then
    # All YAML except docker-compose.yml and excluded files
    TARGETS=()
    while IFS= read -r f; do
        is_excluded "$f" || TARGETS+=("$f")
    done < <(find "$ROOT/Deployment" -maxdepth 1 -name '*.yml' -exec basename {} \;)
elif [[ $# -gt 0 ]]; then
    TARGETS=("$@")
else
    die "usage: publish-config.sh [--dry-run] <config.yml>... | --all"
fi

# Validate targets before touching the VM.
for conf in "${TARGETS[@]}"; do
    is_excluded "$conf" && die "refusing to push $conf (excluded)"
    [[ -f "$ROOT/Deployment/$conf" ]] || die "$conf not found in Deployment/"
done

if [[ "$DRY_RUN" == true ]]; then
    echo "==> dry-run: would push ${#TARGETS[@]} config(s) to $VM"
    for conf in "${TARGETS[@]}"; do echo "    $conf"; done
    exit 0
fi

echo "==> pushing ${#TARGETS[@]} config(s) to VM"
for conf in "${TARGETS[@]}"; do
    echo "    $conf"
    # Exit code is 0 even if it wrote to /home/ubuntu/Food due to spaces.
    rsync -az -e "ssh -i $SSH_KEY" "$ROOT/Deployment/$conf" "$REMOTE_DIR/$conf"

    # Compare md5 to prove it landed exactly where we wanted.
    local_md5="$(md5 -q "$ROOT/Deployment/$conf")"
    remote_md5="$(remote "md5sum '$REMOTE_PATH_MD5/$conf' 2>/dev/null | cut -d' ' -f1")"
    [[ "$local_md5" == "$remote_md5" ]] || die "$conf failed md5 verification after sync. It likely wrote to /home/ubuntu/Food instead of the target directory."
done

echo "==> done"
echo "    Config pushed, but no services were restarted."
echo "    Run: Deployment/deploy.sh --config <service>... to restart the readers."
