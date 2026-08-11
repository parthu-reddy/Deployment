#!/bin/bash

SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"
REMOTE_USER="ubuntu"
REMOTE_HOST="140.245.225.221"
DB_PASS="***REMOVED***"
COMPOSE_DIR="Food Delivery.nosync/Deployment"

echo "Stopping microservices to release DB connections..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
    "cd '$COMPOSE_DIR' && docker compose stop customer-service restaurant-service delivery-service identity-service government-id-service payment-gateway communication-integration ledger-service chat-service"

for db in identity_db restaurant_db food_delivery delivery_db government_id_db payment_db notification_db ledger_db chat_db; do
    echo "Wiping database $db..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
        "cd '$COMPOSE_DIR' && docker compose exec -T -e PGPASSWORD=$DB_PASS postgres psql -h 127.0.0.1 -U postgres -d $db -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'"
done

echo "Wiping Redis cache..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
    "cd '$COMPOSE_DIR' && docker compose exec -T redis redis-cli FLUSHALL"


echo "Creating postgis extension in restaurant_db..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
    "cd '$COMPOSE_DIR' && docker compose exec -T -e PGPASSWORD=$DB_PASS postgres psql -h 127.0.0.1 -U postgres -d restaurant_db -c 'CREATE EXTENSION IF NOT EXISTS postgis;'"

echo "Restarting microservices so they rebuild their schemas..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
    "cd '$COMPOSE_DIR' && docker compose start identity-service restaurant-service customer-service delivery-service government-id-service payment-gateway communication-integration ledger-service chat-service"

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

echo "Database wipe and schema recreation complete!"
