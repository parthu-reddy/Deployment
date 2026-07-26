#!/bin/bash

SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"
REMOTE_USER="ubuntu"
REMOTE_HOST="140.245.225.221"
DB_PASS="***REMOVED***"
COMPOSE_DIR="Food Delivery.nosync/Deployment"

echo "Stopping microservices to release DB connections..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
    "cd '$COMPOSE_DIR' && docker compose stop customer-service restaurant-service delivery-service identity-service government-id-service"

for db in identity_db restaurant_db food_delivery delivery_db government_id_db; do
    echo "Wiping database $db..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
        "cd '$COMPOSE_DIR' && docker compose exec -T -e PGPASSWORD=$DB_PASS postgres psql -h 127.0.0.1 -U postgres -d $db -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'"
done

echo "Creating postgis extension in restaurant_db..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
    "cd '$COMPOSE_DIR' && docker compose exec -T -e PGPASSWORD=$DB_PASS postgres psql -h 127.0.0.1 -U postgres -d restaurant_db -c 'CREATE EXTENSION IF NOT EXISTS postgis;'"

echo "Restarting microservices so they rebuild their schemas..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
    "cd '$COMPOSE_DIR' && docker compose start identity-service restaurant-service customer-service delivery-service government-id-service"

echo "Waiting 60 seconds for Spring Boot services to fully boot up and generate their database schemas..."
sleep 60
echo "Database wipe and schema recreation complete!"
