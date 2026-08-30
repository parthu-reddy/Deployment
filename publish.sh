#!/usr/bin/env bash
#
# Build and push one or more service images from THIS machine, and record their tags.
#
# The VM does not build. It pulls. See RandomDocuments/DeploymentRedesign_2026-08-29/Phase1_*.
#
#   Deployment/publish.sh customer-service [more-services...]
#   Deployment/publish.sh --all
#
# Requires REGISTRY (e.g. bom.ocir.io/<tenancy-namespace>) and a prior `docker login`.
# Does NOT run Maven: build the jars with FoodDeliveryContracts/build_verify.sh first, so what
# ships is what was tested. A publish script that can also build will eventually ship something
# the gates never saw.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="$ROOT/Deployment/service-map.tsv"
VERSIONS="$ROOT/Deployment/.versions"
PLATFORM="linux/arm64"   # the VM is aarch64; this Mac is arm64, so builds are native

die() { echo "publish: $*" >&2; exit 1; }

[[ -f "$MAP" ]] || die "missing $MAP (Phase 1 generates it)"
[[ -n "${REGISTRY:-}" ]] || die "REGISTRY is not set (e.g. export REGISTRY=bom.ocir.io/<namespace>)"

# Fail before building rather than after: a push that fails at the end wastes the whole build.
docker system info >/dev/null 2>&1 || die "docker is not running"
if ! grep -q "$(echo "$REGISTRY" | cut -d/ -f1)" "${DOCKER_CONFIG:-$HOME/.docker}/config.json" 2>/dev/null; then
    die "not logged in to ${REGISTRY%%/*} -- run: docker login ${REGISTRY%%/*}"
fi

module_for() {   # compose-service -> module dir
    awk -F'\t' -v s="$1" '!/^#/ && $2==s {print $1; found=1} END{exit !found}' "$MAP"
}

all_services() { awk -F'\t' '!/^#/ && NF==2 {print $2}' "$MAP"; }

tag_for() {      # module dir -> <short-sha>[-dirty]
    local module="$1" dir="$ROOT/$module" sha
    [[ -d "$dir/.git" ]] || die "$module is not a git repository; cannot derive a tag"
    sha="$(git -C "$dir" rev-parse --short HEAD)"
    # -dirty is deliberate, not a warning to silence: deploying uncommitted work is normal here,
    # and the tag must say so rather than name a tree no commit describes.
    [[ -n "$(git -C "$dir" status --porcelain)" ]] && sha="${sha}-dirty"
    echo "$sha"
}

record() {       # compose-service, tag  ->  .versions
    local var="$(echo "$1" | tr 'a-z-' 'A-Z_')_TAG"
    touch "$VERSIONS"
    grep -v "^${var}=" "$VERSIONS" > "$VERSIONS.tmp" 2>/dev/null || true
    echo "${var}=$2" >> "$VERSIONS.tmp"
    LC_ALL=C sort -o "$VERSIONS" "$VERSIONS.tmp"
    rm -f "$VERSIONS.tmp"
}

if [[ "${1:-}" == "--all" ]]; then
    mapfile -t SERVICES < <(all_services)
else
    [[ $# -gt 0 ]] || die "usage: publish.sh <compose-service>... | --all"
    SERVICES=("$@")
fi

for svc in "${SERVICES[@]}"; do
    module="$(module_for "$svc")" || die "unknown service '$svc'. Valid: $(all_services | tr '\n' ' ')"
    tag="$(tag_for "$module")"
    image="$REGISTRY/food-delivery/$svc:$tag"

    # Every Dockerfile COPYs <Module>/target/*.jar, so the reactor build must have run.
    # The UI is the exception: its Dockerfile copies a Vite dist/.
    if [[ "$module" == "FoodDeliveryAppUI" ]]; then
        [[ -d "$ROOT/$module/dist" ]] || die "$module/dist missing -- run: (cd $module && npm ci && npm run build)"
    elif ! compgen -G "$ROOT/$module/target/*-SNAPSHOT.jar" >/dev/null; then
        die "$module/target/*-SNAPSHOT.jar missing -- run: bash FoodDeliveryContracts/build_verify.sh"
    else
        # Existing is not the same as current. On 2026-08-30 a jar built at 07:52 was published for
        # a source change made at 09:46: `mvn compile` had been run, which produces classes but no
        # jar, so the image shipped without the change and the deploy reported success. Staleness
        # must be checked, not assumed.
        jar="$(ls -t "$ROOT/$module"/target/*-SNAPSHOT.jar | head -1)"
        newer="$(find "$ROOT/$module/src" -name '*.java' -newer "$jar" -print -quit 2>/dev/null)"
        if [[ -n "$newer" ]]; then
            die "$module: $(basename "$jar") is older than $(basename "$newer"). The jar predates the source. Run: bash FoodDeliveryContracts/build_verify.sh"
        fi
    fi

    echo "==> $svc  ($module @ $tag)"
    docker buildx build \
        --platform "$PLATFORM" \
        -f "$ROOT/$module/Dockerfile" \
        -t "$image" \
        --push \
        "$ROOT" </dev/null

    record "$svc" "$tag"
    echo "    pushed $image"
done

echo
echo "Recorded in Deployment/.versions:"
for svc in "${SERVICES[@]}"; do
    grep "^$(echo "$svc" | tr 'a-z-' 'A-Z_')_TAG=" "$VERSIONS" | sed 's/^/  /'
done
echo
echo "Commit .versions -- its git history is the deployment history that --rollback reads."
