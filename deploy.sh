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
VERSIONS_DIR="$ROOT/Deployment/env_deployments/dev"
VERSIONS_LEGACY="$ROOT/Deployment/.versions"
LOG="$ROOT/Deployment/DEPLOY_LOG.md"
SSH_KEY="${SSH_KEY:-/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key}"
VM="${VM:-ubuntu@140.245.234.137}"
REMOTE="Food Delivery.nosync/Deployment"
# Scales with the batch: one service comes up in well under a minute, but 20 JVMs starting
# together on 4 cores took ~5 minutes. A fixed 180s reported failure on a deploy that had
# actually succeeded, which teaches people to ignore a red deploy.
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-}"

die() { echo "deploy: $*" >&2; exit 1; }
remote() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" "$@" </dev/null; }

[[ -f "$MAP" ]] || die "missing $MAP"
[[ -d "$VERSIONS_DIR" ]] || die "missing $VERSIONS_DIR -- publish an image first"
[[ -n "${REGISTRY:-}" ]] || die "REGISTRY is not set"
ROLLBACK=false
SYNC_ENV=false
FRESH=false
if [[ "${1:-}" == "--rollback" ]]; then ROLLBACK=true; shift; fi
if [[ "${1:-}" == "--sync-env" ]]; then SYNC_ENV=true; shift; fi
# --fresh recreates the container instead of reusing one that already matches. Use it when the
# container itself is suspect (bad state, half-applied config); it does NOT touch volumes, so the
# database survives -- wiping data is dummy-data.sh's job.
if [[ "${1:-}" == "--fresh" ]]; then FRESH=true; shift; fi

valid() { awk -F'\t' '!/^#/ && NF>=2 {print $2}' "$MAP"; }

wait_for_health() {
    local svcs=("$@")
    local timeout="${HEALTH_TIMEOUT:-$(( 120 + 30 * ${#svcs[@]} ))}"
    echo "==> waiting for health (timeout ${timeout}s)"
    remote "cd '$REMOTE' && end=\$((SECONDS+$timeout)); while [ \$SECONDS -lt \$end ]; do
      bad=0
      for s in ${svcs[*]}; do
        st=\$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \$s 2>/dev/null || echo missing)
        case \"\$st\" in healthy|running) ;; *) bad=1 ;; esac
      done
      [ \$bad -eq 0 ] && exit 0
      sleep 5
    done; echo 'TIMEOUT waiting for health'; exit 1"
}

config_deploy() {
    [[ $# -gt 0 ]] || die "usage: deploy.sh --config <config.yml>..."
    
    # 1. Ship configs
    "$ROOT/Deployment/publish-config.sh" "$@" || exit $?
    
    # 2. Derive services
    local svcs=() all=false
    for conf in "$@"; do
        if [[ "$conf" == "application.yml" ]]; then
            all=true
        elif [[ "$conf" == "api-gateway.yml" ]]; then
            svcs+=("api-gateway")
        else
            # Extract spring.application.name using bash native reading
            local name=""
            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
                    name="${BASH_REMATCH[1]}"
                    break
                fi
            done < "$ROOT/Deployment/$conf"
            [[ -n "$name" ]] && svcs+=("$name")
        fi
    done
    
    if [[ "$all" == true ]]; then
        svcs=()
        while IFS=$'\t' read -r _ s; do
            [[ "$s" != "eureka-server" && "$s" != "config-service" ]] && svcs+=("$s")
        done < <(valid)
        echo "WARNING: application.yml changed. This will restart EVERY application service."
        read -p "Continue? [y/N] " confirm </dev/tty
        [[ "${confirm,,}" == "y" ]] || exit 1
    fi
    
    [[ ${#svcs[@]} -eq 0 ]] && return 0
    
    # Deduplicate svcs array (Bash 3.2 compatible)
    local uniq_svcs=()
    local s us found
    for s in "${svcs[@]}"; do
        found=0
        for us in "${uniq_svcs[@]:-}"; do
            if [[ "$s" == "$us" ]]; then found=1; break; fi
        done
        [[ $found -eq 0 ]] && uniq_svcs+=("$s")
    done
    
    # 3. Restart and wait
    echo "==> restarting config consumers"
    remote "cd '$REMOTE' && docker compose restart ${uniq_svcs[*]}"
    wait_for_health "${uniq_svcs[@]}"
    echo "==> config restart complete"
}

if [[ "${1:-}" == "--config" ]]; then
    shift
    config_deploy "$@"
    exit 0
fi

[[ $# -gt 0 || "$SYNC_ENV" == true ]] \
    || die "usage: deploy.sh [--rollback <service> | --sync-env | --fresh | --config <config.yml>] <compose-service>..."

valid() { awk -F'\t' '!/^#/ && NF>=2 {print $2}' "$MAP"; }

# Every REGISTRY/tag pair, straight from .versions.
versions_envs() {
    local e="REGISTRY=$REGISTRY" f line
    for f in "$VERSIONS_DIR"/*.env; do
        [[ -f "$f" ]] || continue
        while IFS= read -r line; do
            case "$line" in ''|\#*) continue;; esac
            e="$e $line"
        done < "$f"
    done
    echo "$e"
}

# Persist those values into the VM's .env. Without this the VM cannot resolve its own images:
# `docker compose config --images` there returned "/food-delivery/eureka-server-1:" -- no registry,
# no tag -- because the tags only ever existed in this script's environment. Any compose command run
# on the VM by hand was operating on a different world than the one actually running.
# The 14 secret keys already in .env are preserved; only REGISTRY and *_TAG lines are rewritten.
persist_env() {   # env-string
    local lines
    # Deduplicate by key, keeping the LAST value. The deploy path deliberately re-states the tags of
    # the services being deployed after listing all of .versions, so the string arrives with one
    # duplicate per deployed service. Written straight out, .env grew an extra line on every deploy.
    lines="$(printf '%s\n' $1 | awk -F= '!/^$/ {a[$1]=$0; if (!($1 in o)) o[$1]=++n} END {for (k in a) printf "%d\t%s\n", o[k], a[k]}' | sort -n | cut -f2- | sed 's/$/\\n/' | tr -d '\n')"
    remote "cd '$REMOTE' && umask 077 && touch .env && \
        { grep -vE '^(REGISTRY|[A-Z0-9_]+_TAG)=' .env || true; } > .env.new && \
        printf '$lines' >> .env.new && mv .env.new .env"
    # Counted from the deduplicated lines, not the input: the input carries one duplicate per
    # deployed service, so counting it reported 21 tags while 20 were written.
    echo "    VM .env now pins REGISTRY and $(( $(printf '%b' "$lines" | grep -c '_TAG=') )) image tags"
}

if [[ "$SYNC_ENV" == true ]]; then
    echo "==> syncing REGISTRY and image tags into the VM's .env"
    persist_env "$(versions_envs)"
    exit 0
fi
module_for() { awk -F'\t' -v s="$1" '!/^#/ && $2==s {print $1; f=1} END{exit !f}' "$MAP"; }

# Classify the migrations introduced between two tags of a service.
#
# Rolling back an image does NOT roll back the database. Crossing an ADDITIVE migration backwards is
# safe -- the old code ignores columns it does not know about, which is what expand/contract in
# SCHEMA_POLICY.md exists to guarantee. Crossing a DESTRUCTIVE one is not: the old code queries
# something that no longer exists and fails at request time, not at startup.
#
# Classified here, at deploy time, and written to DEPLOY_LOG.md. Working it out during an outage is
# exactly when it would be got wrong.
destructive_between() {   # module, from-sha, to-sha  ->  prints offending files, exit 0 if any
    local module="$1" from="$2" to="$3" dir="$ROOT/$1" found=""
    [[ -d "$dir/.git" ]] || return 1
    git -C "$dir" cat-file -e "${from}^{commit}" 2>/dev/null || return 1
    local changed
    changed="$(git -C "$dir" diff --name-only "$from" "$to" -- 'src/main/resources/db/migration' 2>/dev/null)"
    [[ -n "$changed" ]] || return 1
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        if git -C "$dir" show "$to:$f" 2>/dev/null \
             | sed 's/--.*$//' \
             | grep -qiE 'DROP[[:space:]]+COLUMN|DROP[[:space:]]+TABLE|RENAME|ALTER[[:space:]]+COLUMN[^,;]*TYPE'; then
            found="$found ${f##*/}"
        fi
    done <<< "$changed"
    [[ -n "$found" ]] && { echo "${found# }"; return 0; }
    return 1
}


# Resolve everything locally before touching the VM: a typo must cost a second, not a failed
# half-deploy. This retires the 7 stale service names the old per-service scripts carried.
if [[ "$ROLLBACK" == true ]]; then
    # One service. A fleet-wide rollback on a 4-core box is a memory event, and the destructive
    # check below is per-service anyway.
    [[ $# -eq 1 ]] || die "--rollback takes exactly one service"
    svc="$1"
    valid | grep -qx "$svc" || die "unknown service '$svc'"
    var="$(echo "$svc" | tr 'a-z-' 'A-Z_')_TAG"
    cur=""
    if [[ -f "$VERSIONS_DIR/$svc.env" ]]; then
        cur="$(awk -F= -v v="$var" '$1==v {print $2}' "$VERSIONS_DIR/$svc.env")"
    else
        cur="$(awk -F= -v v="$var" '$1==v {print $2}' "$VERSIONS_LEGACY")"
    fi

    # The git history IS the deployment history.
    prev=""
    while IFS= read -r sha; do
        t="$(git -C "$ROOT/Deployment" show "$sha:env_deployments/dev/$svc.env" 2>/dev/null | awk -F= -v v="$var" '$1==v {print $2}')"
        [[ -n "$t" && "$t" != "$cur" ]] && { prev="$t"; break; }
    done < <(git -C "$ROOT/Deployment" log --format=%H -- "env_deployments/dev/$svc.env" 2>/dev/null || true)
    
    if [[ -z "$prev" ]]; then
        while IFS= read -r sha; do
            t="$(git -C "$ROOT/Deployment" show "$sha:.versions" 2>/dev/null | awk -F= -v v="$var" '$1==v {print $2}')"
            [[ -n "$t" && "$t" != "$cur" ]] && { prev="$t"; break; }
        done < <(git -C "$ROOT/Deployment" log --format=%H -- .versions 2>/dev/null || true)
    fi
    [[ -n "$prev" ]] || die "no previous tag for $svc in history -- nothing to roll back to"

    # Confirm the target image still exists in the registry BEFORE anything is stopped. A rollback
    # that discovers the image is gone after taking the service down has turned a bad deploy into an
    # outage. Checked from the VM, which is what actually pulls, using its pull-only credential.
    if ! remote "docker manifest inspect '$REGISTRY/food-delivery/$svc:$prev' >/dev/null 2>&1"; then
        die "refusing: $REGISTRY/food-delivery/$svc:$prev is not in the registry.
Nothing has been stopped. Rolling back to a tag that cannot be pulled would take $svc down."
    fi

    # Refuse to cross a destructive migration: the old image would query columns that no longer
    # exist, failing at request time rather than at startup.
    module="$(module_for "$svc" || true)"
    if [[ -n "$module" ]] && hits="$(destructive_between "$module" "${prev%-dirty}" "${cur%-dirty}")"; then
        die "refusing: $cur shipped a destructive migration ($hits).
Rolling back to $prev would run the old image against a schema it cannot query.
Recovery from here is a forward fix, not a rollback."
    fi
    if grep -qE "^\| .* \| $svc \| $cur \|.*\| true \|" "$LOG" 2>/dev/null; then
        die "refusing: DEPLOY_LOG.md records $svc:$cur as destructive. Forward fix required."
    fi

    echo "==> rolling back $svc: $cur -> $prev"
    # Point .env at the previous tag so compose and the verification below agree.
    echo "${var}=${prev}" > "$VERSIONS_DIR/$svc.env"
fi

declare -a SERVICES=() IMAGES=()
for svc in "$@"; do
    valid | grep -qx "$svc" || die "unknown service '$svc'
valid services:
$(valid | sed 's/^/  /')"
    var="$(echo "$svc" | tr 'a-z-' 'A-Z_')_TAG"
    tag=""
    if [[ -f "$VERSIONS_DIR/$svc.env" ]]; then
        tag="$(awk -F= -v v="$var" '$1==v {print $2}' "$VERSIONS_DIR/$svc.env")"
    else
        tag="$(awk -F= -v v="$var" '$1==v {print $2}' "$VERSIONS_LEGACY")"
    fi
    [[ -n "$tag" ]] || die "no tag recorded for $svc -- run: Deployment/publish.sh $svc"
    SERVICES+=("$svc")
    IMAGES+=("$REGISTRY/food-delivery/$svc:$tag")
done

contains_service() {
    local wanted="$1" service
    shift
    for service in "$@"; do
        [[ "$service" == "$wanted" ]] && return 0
    done
    return 1
}

desired_image_for() {
    local service="$1" variable tag
    variable="$(echo "$service" | tr 'a-z-' 'A-Z_')_TAG"
    tag=""
    if [[ -f "$VERSIONS_DIR/$service.env" ]]; then
        tag="$(awk -F= -v v="$variable" '$1==v {print $2}' "$VERSIONS_DIR/$service.env")"
    else
        tag="$(awk -F= -v v="$variable" '$1==v {print $2}' "$VERSIONS_LEGACY")"
    fi
    [[ -n "$tag" ]] || die "no tag recorded for contract producer $service"
    echo "$REGISTRY/food-delivery/$service:$tag"
}

# These services exchange strict, required-field Kafka contracts. A consumer may be deployed only
# after its producer is on the intended workspace version. When both are selected below, startup is
# serialized producer-first. When only the consumer is selected, this guard verifies the producer
# already matches .versions before any image is pulled or container is changed.
CONTRACT_CHAIN=(customer-service restaurant-service delivery-service maps-integration)
for chain_index in 1 2 3; do
    consumer="${CONTRACT_CHAIN[$chain_index]}"
    producer="${CONTRACT_CHAIN[$((chain_index - 1))]}"
    contains_service "$consumer" "${SERVICES[@]}" || continue
    contains_service "$producer" "${SERVICES[@]}" && continue

    wanted_producer="$(desired_image_for "$producer")"
    running_producer="$(remote "docker inspect -f '{{.Config.Image}}' '$producer' 2>/dev/null || echo none")"
    [[ "$running_producer" == "$wanted_producer" ]] || die "refusing to deploy $consumer before its contract producer.
$producer is running: $running_producer
$producer must run:   $wanted_producer
Deploy both in one producer-first operation:
  Deployment/deploy.sh $producer $consumer"
done

echo "==> deploying ${#SERVICES[@]} service(s) to $VM"
for i in "${!SERVICES[@]}"; do echo "    ${SERVICES[$i]} -> ${IMAGES[$i]}"; done

before="$(remote "cd '$REMOTE' && for s in ${SERVICES[*]}; do printf '%s=%s\n' \"\$s\" \"\$(docker inspect -f '{{.Config.Image}}' \$s 2>/dev/null || echo none)\"; done")"

# compose interpolates ${REGISTRY} and ${<SVC>_TAG} from the shell it runs in, and .versions lives
# on this machine -- so the values are passed explicitly rather than assumed present on the VM.
# EVERY tag, not just the ones being deployed. `docker compose up -d <one-service>` still parses
# the whole file, so an unset ${X_TAG} for any other service resolves to a blank string and
# compose fails with "invalid reference format" on an image that was never being touched.
ENVS="$(versions_envs)"

# The deployed services use the tag resolved above, which is the same value unless .versions
# changed under us mid-run; re-stating them makes the intent explicit rather than implicit.
for i in "${!SERVICES[@]}"; do
    ENVS="$ENVS $(echo "${SERVICES[$i]}" | tr 'a-z-' 'A-Z_')_TAG=${IMAGES[$i]##*:}"
done

# Pull first so a registry failure cannot interrupt the ordered startup after only some consumers
# have moved. --remove-orphans keeps undeclared containers from accumulating silently.
UP_FLAGS="--remove-orphans"
[[ "$FRESH" == true ]] && UP_FLAGS="$UP_FLAGS --force-recreate"
remote "cd '$REMOTE' && env $ENVS docker compose pull ${SERVICES[*]}"

# Unrelated services can start together. Contract-linked services are deliberately excluded from
# this batch and then started one at a time in producer-to-consumer order. Waiting for each producer
# to become healthy closes the version-skew window that previously allowed RestaurantApplication to
# consume an ORDER_PAID payload from an older CustomerApplication.
declare -a OTHER_SERVICES=()
for svc in "${SERVICES[@]}"; do
    contains_service "$svc" "${CONTRACT_CHAIN[@]}" || OTHER_SERVICES+=("$svc")
done
if [[ ${#OTHER_SERVICES[@]} -gt 0 ]]; then
    echo "==> starting independent services: ${OTHER_SERVICES[*]}"
    remote "cd '$REMOTE' && env $ENVS docker compose up -d $UP_FLAGS ${OTHER_SERVICES[*]}"
    wait_for_health "${OTHER_SERVICES[@]}"
fi

for svc in "${CONTRACT_CHAIN[@]}"; do
    contains_service "$svc" "${SERVICES[@]}" || continue
    echo "==> starting contract service: $svc"
    remote "cd '$REMOTE' && env $ENVS docker compose up -d $UP_FLAGS $svc"
    wait_for_health "$svc"
done

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

persist_env "$ENVS"

# Reclaim disk from superseded image tags. Every deploy pulls a new git-sha tag and the previous one
# stays behind: 50 images / 16GB accumulated, a third of it reclaimable. This removes only images no
# container references -- the 27 running services keep theirs -- and anything removed is still in
# OCIR, so --rollback (which pulls) is unaffected. NO_PRUNE=1 skips it.
if [[ "${NO_PRUNE:-}" != "1" ]]; then
    freed="$(remote "docker image prune -a -f 2>/dev/null | tail -1")"
    [[ -n "$freed" ]] && echo "    pruned superseded images on the VM: $freed"
fi

# One row per service, not per invocation: --rollback resolves a single service and cannot read a
# row that lumps twenty together.
[[ -s "$LOG" ]] || printf '| when | service | tag | migrations | destructive | by |\n|---|---|---|---|---|---|\n' > "$LOG"
for i in "${!SERVICES[@]}"; do
    svc="${SERVICES[$i]}"; tag="${IMAGES[$i]##*:}"
    prev="$(echo "$before" | awk -F= -v s="$svc" '$1==s {print $2}')"; prev="${prev##*:}"
    module="$(module_for "$svc" || true)"
    mig="-"; destr="false"
    # A rollback moves BACKWARDS, so classifying prev..tag would ask "what did the older tag
    # introduce relative to the newer one" -- the reverse of the question. The destructive check in
    # the rollback path has already run and refused if it mattered; record it as its own kind of
    # entry instead of one that reads like a normal deploy.
    if [[ "$ROLLBACK" == true ]]; then
        mig="rollback from $prev"
    elif [[ -n "$module" && -n "$prev" && "$prev" != "none" && "$prev" != "$tag" ]]; then
        if hits="$(destructive_between "$module" "${prev%-dirty}" "${tag%-dirty}")"; then
            mig="$hits"; destr="true"
        else
            mig="additive-or-none"
        fi
    fi
    printf '| %s | %s | %s | %s | %s | %s |\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$svc" "$tag" "$mig" "$destr" \
        "$(git config user.email 2>/dev/null || whoami)" >> "$LOG"
    [[ "$destr" == "true" ]] && echo "    NOTE $svc shipped a destructive migration ($mig) -- rollback past this point will be refused"
done

for s in "${SERVICES[@]}"; do
    [[ "$s" == "food-delivery-app-ui" ]] && echo "NOTE: hard-refresh the browser (Cmd+Shift+R) -- Vite bundles are cached client-side."
done
echo "==> done"
