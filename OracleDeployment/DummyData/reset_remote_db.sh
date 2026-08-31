#!/usr/bin/env bash
#
# Wipe every application database on the Oracle VM and let Flyway rebuild the schemas.
#
#   DummyData/reset_remote_db.sh
#
# The schemas are rebuilt by FLYWAY, not by Hibernate. Every service runs `ddl-auto: validate`, so
# Hibernate creates nothing and fails startup if the tables are not what it expects. Dropping the
# public schema also drops `flyway_schema_history`, so on restart Flyway re-applies every migration
# from V1 against an empty database. That is why a wipe is safe here and why the migrations must
# stay runnable from scratch (see Deployment/SCHEMA_POLICY.md).
set -uo pipefail

SSH_KEY="${SSH_KEY:-/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key}"
VM="${VM:-ubuntu@140.245.234.137}"
COMPOSE_DIR="Food Delivery.nosync/Deployment"

# No credentials on this machine. psql runs inside the postgres container and reads the password
# from that container's own environment, so it never appears in this script, in the ssh command
# line, or in the VM's process list. kartoza/postgis names it POSTGRES_PASS, not POSTGRES_PASSWORD.
remote() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" "$@" </dev/null; }
# The SQL is base64-encoded on the way in. It passes through three shells -- local bash, the VM's
# shell, and `sh -c` inside the container -- and any single quote in the statement (every literal,
# e.g. table_name='customers') closes the `sh -c '...'` quoting and silently truncates the query.
# Base64 is alphanumeric plus +/= and survives all three layers untouched.
psql_db() {  # database, sql
    local b64
    b64="$(printf '%s' "$2" | base64 | tr -d '\n')"
    remote "cd '$COMPOSE_DIR' && docker compose exec -T postgres sh -c 'echo $b64 | base64 -d | PGPASSWORD=\$POSTGRES_PASS psql -h 127.0.0.1 -U postgres -d $1 -tA -f -'" 2>/dev/null
}

# Every service that owns a database. wallet, campaign and budget-pacing were missing here: their
# databases were left populated while the users those rows referenced were deleted, leaving wallet
# balances and campaigns pointing at customers that no longer existed.
SERVICES="customer-service restaurant-service delivery-service identity-service \
government-id-service payment-gateway communication-integration ledger-service chat-service \
wallet-service campaign-service budget-pacing-service"

DBS="identity_db restaurant_db customer_db delivery_db government_id_db payment_db notification_db \
ledger_db chat_db wallet_db campaign_db budget_db"

# reviews_db and ondc_db are deliberately excluded -- reviews-service and ondc-integration-service
# are parked and not running, so nothing would re-migrate them after a wipe.

# Extensions live IN the public schema, so `DROP SCHEMA public CASCADE` removes them. Recreating
# only restaurant_db's postgis (as this script used to) left customer_db and delivery_db without
# postgis and payment_db without pgcrypto, and their Flyway migrations then failed on boot.
EXTENSIONS="restaurant_db:postgis customer_db:postgis delivery_db:postgis payment_db:pgcrypto"

# Sentinel tables live in schema_sentinels.tsv, read by this script and by wait_for_schemas.sh.
# Two hand-maintained copies of this list had already drifted -- one carried 7 databases, the other 10.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SENTINELS="$(awk -F'\t' '!/^#/ && NF==2 {printf "%s:%s ", $1, $2}' "$HERE/schema_sentinels.tsv")"
[ -n "$SENTINELS" ] || { echo "reset: schema_sentinels.tsv is empty or missing" >&2; exit 1; }

# This drops the public schema of twelve databases on the live VM. There is no second environment
# and no backup step anywhere in this flow, so the prompt is the only thing between a typo and an
# afternoon of regenerating data. --yes skips it for scripted use.
if [ "${1:-}" != "--yes" ]; then
    echo "About to DROP SCHEMA public CASCADE on $(echo $DBS | wc -w | tr -d ' ') databases on $VM."
    echo "All data is lost. There is no backup."
    printf 'Type WIPE to continue: '
    read -r confirm
    [ "$confirm" = "WIPE" ] || { echo "aborted"; exit 1; }
fi

echo "==> stopping services to release database connections"
remote "cd '$COMPOSE_DIR' && docker compose stop $SERVICES"

for db in $DBS; do
    echo "    wiping $db"
    psql_db "$db" "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >/dev/null
done

echo "==> recreating extensions"
for pair in $EXTENSIONS; do
    db="${pair%%:*}"; ext="${pair##*:}"
    echo "    $db <- $ext"
    psql_db "$db" "CREATE EXTENSION IF NOT EXISTS $ext;" >/dev/null
done

echo "==> flushing redis"
remote "cd '$COMPOSE_DIR' && docker compose exec -T redis redis-cli FLUSHALL" >/dev/null

echo "==> restarting services so Flyway re-applies every migration"
remote "cd '$COMPOSE_DIR' && docker compose start $SERVICES"

echo "==> waiting for Flyway to finish (sentinel tables)"
DEADLINE=$(( $(date +%s) + 900 ))
for pair in $SENTINELS; do
    db="${pair%%:*}"; table="${pair##*:}"
    printf '    %-20s %-24s' "$db" "$table"
    while true; do
        if [ "$(date +%s)" -gt "$DEADLINE" ]; then
            echo "TIMEOUT"
            echo "reset: gave up after 15 minutes waiting for $table in $db." >&2
            echo "Check the service log -- a failed migration stops Flyway and the table never appears:" >&2
            echo "  ssh -i \$SSH_KEY $VM \"cd '$COMPOSE_DIR' && docker compose logs --tail=100 <service>\"" >&2
            exit 1
        fi
        exists="$(psql_db "$db" "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='public' AND table_name='$table');")"
        case "$exists" in *t*) echo "ok"; break;; esac
        sleep 5
    done
done

echo "==> database wipe and schema rebuild complete"
echo "    Next: follow DummyData/execution_order.md to insert the dummy data."
