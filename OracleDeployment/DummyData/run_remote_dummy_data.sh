#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
MODE="${1:-all}"
[[ "$MODE" = all || "$MODE" = --scenarios-only ]] || { echo "Usage: $0 [--scenarios-only]" >&2; exit 2; }

# Configuration
SSH_KEY="${SSH_KEY:-/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key}"
VM="${VM:-ubuntu@140.245.234.137}"
export SSH_KEY VM
# Credentials come from Deployment/.env, which is NOT tracked in git. It is written either by hand
# or by fetch_secrets_from_vault.sh. This script previously embedded the Postgres password inline;
# rotating .env would then have broken it, and the quickest fix under pressure is to paste the new
# password straight back in -- recreating the problem with a fresh secret.
# No credentials on this machine at all. psql runs inside the postgres container and reads the
# password from that container's own environment, so it appears neither in this script, nor in the
# ssh command line, nor in the VM's process list. The kartoza/postgis image names it POSTGRES_PASS.
# The SQL still arrives on stdin, so no statement is ever quoted into a command line.
COMPOSE_DIR="Food Delivery.nosync/Deployment"

# Helper function to run a SQL file against a specific remote database
run_sql() {
    local db_name=$1
    local sql_file=$2
    
    echo "Running $sql_file on remote database $db_name..."
    if ssh -o BatchMode=yes -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" \
        "cd '$COMPOSE_DIR' && docker compose exec -T postgres sh -c 'PGPASSWORD=\$POSTGRES_PASS psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres -d $db_name'" < "$sql_file"; then
        echo "Successfully executed $sql_file on $db_name"
    else
        echo "Error executing $sql_file on $db_name"
        exit 1
    fi
}

# Inspect only the profile setting; never copy credentials or the container environment.
profiles="$(ssh -o BatchMode=yes -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" \
    "cd '$COMPOSE_DIR' && docker compose exec -T identity-service printenv SPRING_PROFILES_ACTIVE" </dev/null | tr -d '[:space:]')"
case ",$profiles," in *,dev,*) ;; *) echo 'Seed loading requires Dev' >&2; exit 1;; esac
case ",$profiles," in *,prod,*) echo 'Seed loading refuses prod' >&2; exit 1;; esac
python3 "$HERE/validate_seed_data.py"
bash "$HERE/wait_for_schemas.sh" 300
echo "Starting remote dummy data insertion..."

if [[ "$MODE" = all ]]; then

# 1. Identity DB (MUST BE FIRST)
run_sql "identity_db" "dummy_riders_customers_identity.sql"
run_sql "identity_db" "dummy_identity_data.sql"

# 2. Customer DB (Uses the customer_db database)
run_sql "customer_db" "dummy_customers.sql"
run_sql "customer_db" "dummy_customer_data.sql"

# 3. Delivery DB
run_sql "delivery_db" "dummy_riders.sql"
run_sql "delivery_db" "dummy_delivery_data.sql"

# 4. Restaurant DB
run_sql "restaurant_db" "dummy_data.sql"

# 5. Government ID DB
run_sql "government_id_db" "dummy_government_id_brands.sql"
run_sql "government_id_db" "dummy_government_id_executives.sql"

fi

# Baseline and scenario inserts preserve existing fixture state and support partial-load recovery.
run_sql identity_db scenario_identity.sql
run_sql customer_db scenario_customer.sql
run_sql delivery_db scenario_delivery.sql
run_sql restaurant_db scenario_restaurant.sql
run_sql government_id_db scenario_government_id.sql
python3 "$HERE/validate_seed_data.py" --remote
echo "Dummy data loaded and fixture relationships verified."
