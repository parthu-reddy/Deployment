#!/usr/bin/env bash
#
# Block until Flyway has rebuilt every schema. Standalone version of the wait built into
# reset_remote_db.sh -- useful after a deploy, when nothing was wiped.
#
#   DummyData/wait_for_schemas.sh [timeout-seconds]     (default 900)
set -uo pipefail

SSH_KEY="${SSH_KEY:-/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key}"
VM="${VM:-ubuntu@140.245.234.137}"
COMPOSE_DIR="Food Delivery.nosync/Deployment"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/schema_readiness.sh"
TIMEOUT="${1:-900}"

# No credentials on this machine: psql runs inside the postgres container and reads the password
# from that container's own environment. kartoza/postgis names it POSTGRES_PASS.
# The statement is base64-encoded because it passes through three shells and its own single quotes
# (table_name='users') would otherwise close the `sh -c '...'` quoting and truncate the query.
psql_db() {  # database, sql
    local b64
    b64="$(printf '%s' "$2" | base64 | tr -d '\n')"
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" \
        "cd '$COMPOSE_DIR' && docker compose exec -T postgres sh -c 'echo $b64 | base64 -d | PGPASSWORD=\$POSTGRES_PASS psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres -d $1 -tA -f -'" </dev/null 2>/dev/null
}

# One shared list, so this script and reset_remote_db.sh cannot disagree about which schemas exist.
# The table has 4 columns: database, owning-service, sentinel-table, extensions. We read database, owning service and sentinel.
SENTINELS="$(awk -F'\t' '!/^#/ && NF>=3 {printf "%s:%s:%s ", $1, $2, $3}' "$HERE/schema_sentinels.tsv")"
[ -n "$SENTINELS" ] || { echo "wait: schema_sentinels.tsv is empty or missing" >&2; exit 1; }

echo "==> waiting for Flyway to finish (timeout ${TIMEOUT}s)"
DEADLINE=$(( $(date +%s) + TIMEOUT ))
for pair in $SENTINELS; do
    db="${pair%%:*}"; remainder="${pair#*:}"; owner="${remainder%%:*}"; table="${pair##*:}"
    printf '    %-20s %-24s' "$db" "$table"
    while true; do
        if [ "$(date +%s)" -gt "$DEADLINE" ]; then
            echo "TIMEOUT"
            echo "wait: gave up waiting for $table in $db." >&2
            echo "A failed migration stops Flyway and the table never appears -- read the log:" >&2
            echo "  ssh -i \$SSH_KEY $VM \"cd '$COMPOSE_DIR' && docker compose logs --tail=100 <service>\"" >&2
            exit 1
        fi
        if schema_is_ready "$db" "$owner" "$table"; then echo "ok"; break; fi
        sleep 5
    done
done
echo "==> owning services healthy; schema sentinels and Flyway history verified"
