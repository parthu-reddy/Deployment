#!/usr/bin/env bash
#
# ONE command to get a service onto the Oracle VM: build -> publish -> deploy.
#
#   Deployment/ship.sh customer-service              one backend service
#   Deployment/ship.sh food-delivery-app-ui          the UI (npm build, handled automatically)
#   Deployment/ship.sh customer-service wallet-service
#   Deployment/ship.sh --all                         every service
#   Deployment/ship.sh --fresh customer-service      also recreate the container from scratch
#   Deployment/ship.sh --no-build customer-service   jar/dist already current, skip the build
#
# --fresh recreates the CONTAINER. It does not touch the database -- to wipe data and reload dummy
# data, use Deployment/dummy-data.sh.
#
# The three steps underneath (mvn/npm, publish.sh, deploy.sh) still work on their own; this only
# removes the need to remember the order and the module names.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY="$ROOT/Deployment"
MAP="$DEPLOY/service-map.tsv"
FRESH=false
BUILD=true

die() { echo "ship: $*" >&2; exit 1; }
module_for() { awk -F'\t' -v s="$1" '!/^#/ && $2==s {print $1; f=1} END{exit !f}' "$MAP"; }
all_services() { awk -F'\t' '!/^#/ && NF>=2 {print $2}' "$MAP"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fresh)    FRESH=true; shift;;
        --no-build) BUILD=false; shift;;
        --all)      shift; set -- $(all_services) "$@";  break;;
        -h|--help)  sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
        -*)         die "unknown option '$1'";;
        *)          break;;
    esac
done

[[ $# -gt 0 ]] || die "usage: ship.sh [--fresh] [--no-build] <service>... | --all
Valid services:
$(all_services | sed 's/^/  /')"
[[ -n "${REGISTRY:-}" ]] || die "REGISTRY is not set. Run: export REGISTRY=hyd.ocir.io/axekmbadoczl"

SERVICES=("$@")

# Validate every name BEFORE building anything. Discovering a typo after a ten-minute Maven build
# is the kind of thing that makes a deploy feel unreliable.
JAVA_MODULES=(); UI=false
for svc in "${SERVICES[@]}"; do
    module="$(module_for "$svc")" || die "unknown service '$svc'. Valid:
$(all_services | sed 's/^/  /')"
    if [[ "$module" == "FoodDeliveryAppUI" ]]; then UI=true; else JAVA_MODULES+=("$module"); fi
done

# Docker is needed by publish.sh, which runs AFTER the build. Checking it here turns a ten-minute
# Maven build followed by "docker is not running" into an immediate, actionable failure.
docker system info >/dev/null 2>&1 \
    || die "docker is not running. Start Docker Desktop (open -a Docker) and retry."
grep -q "${REGISTRY%%/*}" "${DOCKER_CONFIG:-$HOME/.docker}/config.json" 2>/dev/null \
    || die "not logged in to ${REGISTRY%%/*} -- run: docker login ${REGISTRY%%/*}"

echo "=========================================================="
echo " ship: ${SERVICES[*]}"
echo " build=$BUILD  fresh=$FRESH  registry=$REGISTRY"
echo "=========================================================="

if [[ "$BUILD" == true ]]; then
    if [[ ${#JAVA_MODULES[@]} -gt 0 ]]; then
        # One reactor invocation for all requested modules rather than one per service: -am pulls in
        # CommonLibrary, and building it once instead of N times is most of the wall-clock saving.
        # The parent POM is installed first because it is not part of the aggregator, so a cold
        # ~/.m2 cannot resolve the managed dependency versions without it.
        echo "==> building: ${JAVA_MODULES[*]}"
        PL="$(IFS=,; echo "${JAVA_MODULES[*]}")"
        (cd "$ROOT" && mvn -q -N install -f FoodDeliveryParent/pom.xml)
        (cd "$ROOT" && mvn -q package -pl "$PL" -am -DskipTests)
        echo "    jars built"
    fi
    if [[ "$UI" == true ]]; then
        echo "==> building the UI"
        # An `sudo npm` run on 2026-05-31 left root-owned directories inside ~/.npm/_cacache, so
        # `npm ci` deletes node_modules and then dies with EACCES. Detected here and worked around
        # with a private cache, because otherwise the UI simply cannot be shipped from this machine.
        # `--silent` used to hide the whole thing: the build "succeeded" in 18s having installed
        # nothing, and the failure only surfaced as `vite: command not found`.
        if find "$HOME/.npm/_cacache" -user root -print -quit 2>/dev/null | grep -q .; then
            export NPM_CONFIG_CACHE="$ROOT/Deployment/.npm-cache"
            echo "    NOTE: ~/.npm/_cacache contains root-owned files, using a private cache."
            echo "          Permanent fix (needs your password): sudo chown -R \$(whoami) ~/.npm"
        fi
        (cd "$ROOT/FoodDeliveryAppUI" && npm ci && npm run build)
        [[ -d "$ROOT/FoodDeliveryAppUI/dist" ]] || die "UI build produced no dist/"
        echo "    dist built"
    fi
fi

# publish.sh re-checks that each jar is newer than its sources, so a --no-build run that is actually
# stale is refused rather than silently shipping yesterday's code.
echo "==> publishing"
"$DEPLOY/publish.sh" "${SERVICES[@]}"

echo "==> deploying"
if [[ "$FRESH" == true ]]; then
    "$DEPLOY/deploy.sh" --fresh "${SERVICES[@]}"
else
    "$DEPLOY/deploy.sh" "${SERVICES[@]}"
fi

echo
echo "=========================================================="
echo " ${#SERVICES[@]} service(s) shipped."
echo " Logs:  ssh -i \$SSH_KEY ubuntu@140.245.234.137 \\"
echo "          \"cd 'Food Delivery.nosync/Deployment' && docker compose logs -f ${SERVICES[0]}\""
echo "=========================================================="
