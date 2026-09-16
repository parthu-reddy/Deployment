#!/usr/bin/env bash
#
# ONE command to put dummy data on the Oracle VM.
#
#   Deployment/dummy-data.sh               wipe every database, let Flyway rebuild, then load
#   Deployment/dummy-data.sh --load-only    load into the existing schemas, no wipe
#   Deployment/dummy-data.sh --yes          skip the confirmation prompt
#
# The wipe drops the public schema of twelve databases on the live VM. There is no second
# environment and no backup, so it asks before doing it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DD="$ROOT/Deployment/OracleDeployment/DummyData"
LOAD_ONLY=false
YES=false
for a in "$@"; do
    case "$a" in
        --load-only) LOAD_ONLY=true;;
        --yes)       YES=true;;
        -h|--help)   sed -n '3,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
        *)           echo "dummy-data: unknown option '$a'" >&2; exit 1;;
    esac
done

if [[ "$LOAD_ONLY" != true ]]; then
    echo "==> resetting databases"
    # reset_remote_db.sh now requires a target; --all is the explicit "reset everything".
    if [[ "$YES" == true ]]; then
        "$DD/reset_remote_db.sh" --all --yes
    else
        "$DD/reset_remote_db.sh" --all
    fi
else
    # Loading into schemas that Flyway has not finished building inserts into tables that may not
    # exist yet, and the failure looks like a broken SQL file rather than a timing problem.
    echo "==> confirming schemas are present"
    "$DD/wait_for_schemas.sh" 300
fi

echo "==> loading dummy data"
(cd "$DD" && ./run_remote_dummy_data.sh)

echo
echo "=========================================================="
echo " Dummy data loaded."
echo "=========================================================="
