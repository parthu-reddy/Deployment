#!/bin/bash
# flyway_reset.sh — Clears Flyway schema history for all services
# after merging migrations into a single V1__init_schema.sql.
#
# The existing databases already have the final schema applied.
# Flyway will see V1 with a different checksum than what it has recorded.
# We clear the history and let baseline-on-migrate handle the rest.
#
# Usage: ./flyway_reset.sh
#   Environment variables (from .env or exported):
#     POSTGRES_USER, POSTGRES_PASS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env if present
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${POSTGRES_USER:-postgres}"
PG_PASS="${POSTGRES_PASS:-password}"

export PGPASSWORD="$PG_PASS"

DATABASES=(
    "identity_db"
    "food_delivery"
    "delivery_db"
    "restaurant_db"
    "payment_db"
)

SERVICE_NAMES=(
    "identity-service"
    "customer-service"
    "delivery-service"
    "restaurant-service"
    "payment-service"
)

echo "=== Flyway Schema History Reset ==="
echo "Host: $PG_HOST:$PG_PORT  User: $PG_USER"
echo ""

for i in "${!DATABASES[@]}"; do
    db="${DATABASES[$i]}"
    svc="${SERVICE_NAMES[$i]}"
    echo "--- $svc ($db) ---"
    
    # Check if flyway_schema_history exists
    TABLE_EXISTS=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$db" -tAc \
        "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'flyway_schema_history');" 2>/dev/null || echo "false")

    if [ "$TABLE_EXISTS" = "t" ]; then
        # Drop flyway_schema_history completely
        psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$db" -c \
            "DROP TABLE IF EXISTS flyway_schema_history CASCADE;" 2>/dev/null
        
        echo "  ✅ Cleared history and inserted baseline."
    else
        echo "  ⚠️  No flyway_schema_history table found (skipped)."
    fi
done

unset PGPASSWORD
echo ""
echo "=== Done. Restart microservices to pick up the merged migration. ==="
