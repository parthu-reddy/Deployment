#!/usr/bin/env bash
#
# Reset one or more databases on the Oracle VM and let Flyway rebuild the schemas.
#
#   reset_remote_db.sh <database>...     reset only these databases
#   reset_remote_db.sh --all             reset all twelve, explicitly
#   reset_remote_db.sh --list            show databases, their owning service, and sentinel table
#   reset_remote_db.sh --yes             skip the confirmation prompt (combine with --all or <db>)
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
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TABLE="$HERE/schema_sentinels.tsv"

die() { echo "reset: $*" >&2; exit 1; }

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

[ -f "$TABLE" ] || die "schema_sentinels.tsv missing at $TABLE"

# Parse the widened 4-column table once. reviews_db and ondc_db are excluded (parked).
ALL_DBS="$(awk -F'\t' '!/^#/ && NF>=4 {print $1}' "$TABLE" | tr '\n' ' ')"
ALL_DBS="${ALL_DBS% }"

get_db_prop() {
    # $1 = db, $2 = column number (2=svc, 3=sentinel, 4=exts)
    awk -F'\t' -v db="$1" -v col="$2" '!/^#/ && $1==db {print $col}' "$TABLE"
}

# --- Argument parsing ---
YES=false
ALL=false
LIST=false
TARGETS=""
for arg in "$@"; do
    case "$arg" in
        --yes)  YES=true;;
        --all)  ALL=true;;
        --list) LIST=true;;
        -h|--help) ;;
        *)
            # Validate the database name against the table
            found=false
            for db in $ALL_DBS; do
                [ "$db" = "$arg" ] && { found=true; break; }
            done
            if [ "$found" = false ]; then
                echo "reset: unknown database '$arg'" >&2
                echo "valid databases:" >&2
                for db in $ALL_DBS; do echo "  $db" >&2; done
                exit 1
            fi
            TARGETS="$TARGETS $arg"
            ;;
    esac
done
TARGETS="${TARGETS# }"

if [ "$LIST" = true ]; then
    printf '%-20s %-30s %-24s %s\n' "DATABASE" "OWNING SERVICE" "SENTINEL TABLE" "EXTENSIONS"
    printf '%-20s %-30s %-24s %s\n' "--------" "--------------" "--------------" "----------"
    for db in $ALL_DBS; do
        printf '%-20s %-30s %-24s %s\n' "$db" "$(get_db_prop "$db" 2)" "$(get_db_prop "$db" 3)" "$(get_db_prop "$db" 4)"
    done
    exit 0
fi

# No arguments: print usage and exit non-zero. Never default to --all.
if [ -z "$TARGETS" ] && [ "$ALL" = false ]; then
    echo "usage: reset_remote_db.sh <database>... | --all | --list" >&2
    echo "" >&2
    echo "  <database>...   reset only these databases" >&2
    echo "  --all           reset all $(echo $ALL_DBS | wc -w | tr -d ' ') databases" >&2
    echo "  --list          show the database table" >&2
    echo "  --yes           skip the confirmation prompt" >&2
    echo "" >&2
    echo "valid databases: $ALL_DBS" >&2
    exit 1
fi

if [ "$ALL" = true ]; then
    TARGETS="$ALL_DBS"
fi

DB_COUNT=$(echo $TARGETS | wc -w | tr -d ' ')

# Collect the owning services for the targeted databases only.
SERVICES=""
for db in $TARGETS; do
    svc="$(get_db_prop "$db" 2)"
    # Avoid duplicates (two databases could share a service, unlikely but safe)
    echo "$SERVICES" | grep -qw "$svc" || SERVICES="$SERVICES $svc"
done
SERVICES="${SERVICES# }"

# This drops the public schema of one or more databases on the live VM. There is no second
# environment and no backup step anywhere in this flow, so the prompt is the only thing between
# a typo and an afternoon of regenerating data.
if [ "$YES" != true ]; then
    echo "About to DROP SCHEMA public CASCADE on $DB_COUNT database(s) on $VM:"
    for db in $TARGETS; do echo "  $db ($(get_db_prop "$db" 2))"; done
    echo "All data in these databases is lost. There is no backup."
    printf 'Type WIPE to continue: '
    read -r confirm
    [ "$confirm" = "WIPE" ] || { echo "aborted"; exit 1; }
fi

echo "==> stopping services to release database connections"
echo "    services: $SERVICES"
remote "cd '$COMPOSE_DIR' && docker compose stop $SERVICES"

for db in $TARGETS; do
    echo "    wiping $db"
    psql_db "$db" "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >/dev/null
done

echo "==> recreating extensions"
for db in $TARGETS; do
    exts="$(get_db_prop "$db" 4)"
    [ "$exts" = "-" ] && continue
    for ext in $(echo "$exts" | tr ',' ' '); do
        echo "    $db <- $ext"
        psql_db "$db" "CREATE EXTENSION IF NOT EXISTS $ext;" >/dev/null
    done
done

# Redis is global — flushing it on a targeted reset would destroy every service's cache, not just
# the ones being reset. Only flush under --all.
if [ "$ALL" = true ]; then
    echo "==> flushing redis"
    remote "cd '$COMPOSE_DIR' && docker compose exec -T redis redis-cli FLUSHALL" >/dev/null
else
    echo "    note: redis was NOT flushed (targeted reset; use --all to flush)"
fi

echo "==> restarting services so Flyway re-applies every migration"
echo "    services: $SERVICES"
remote "cd '$COMPOSE_DIR' && docker compose start $SERVICES"

echo "==> waiting for Flyway to finish (sentinel tables)"
DEADLINE=$(( $(date +%s) + 900 ))
for db in $TARGETS; do
    sentinel="$(get_db_prop "$db" 3)"
    printf '    %-20s %-24s' "$db" "$sentinel"
    while true; do
        if [ "$(date +%s)" -gt "$DEADLINE" ]; then
            echo "TIMEOUT"
            echo "reset: gave up after 15 minutes waiting for $sentinel in $db." >&2
            echo "Check the service log -- a failed migration stops Flyway and the table never appears:" >&2
            echo "  ssh -i \$SSH_KEY $VM \"cd '$COMPOSE_DIR' && docker compose logs --tail=100 $(get_db_prop "$db" 2)\"" >&2
            exit 1
        fi
        exists="$(psql_db "$db" "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='public' AND table_name='$sentinel');")"
        case "$exists" in *t*) echo "ok"; break;; esac
        sleep 5
    done
done

echo "==> database reset complete ($DB_COUNT database(s))"
echo "    Next: follow DummyData/execution_order.md to insert the dummy data."
