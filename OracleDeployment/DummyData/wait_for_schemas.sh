#!/bin/bash
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"
REMOTE_USER="ubuntu"
REMOTE_HOST="140.245.234.137"
DB_PASS="***REMOVED***"
COMPOSE_DIR="Food Delivery.nosync/Deployment"

echo "Waiting for Spring Boot microservices to boot up and generate their database schemas..."
for db_table in "identity_db:users" "food_delivery:customers" "delivery_db:delivery_executives" "restaurant_db:brands" "government_id_db:executive_documents" "ledger_db:ledger_entries" "chat_db:chat_sessions"; do
    db="${db_table%%:*}"
    table="${db_table##*:}"
    echo "Waiting for table $table in $db..."
    while true; do
        exists=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
            "cd '$COMPOSE_DIR' && docker compose exec -T -e PGPASSWORD=$DB_PASS postgres psql -h 127.0.0.1 -U postgres -d $db -tAc \"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$table');\"" 2>/dev/null)
        if echo "$exists" | grep -q "t"; then
            echo "Table $table found in $db!"
            break
        fi
        echo "Still waiting for $table in $db..."
        sleep 5
    done
done
echo "All schemas generated!"
