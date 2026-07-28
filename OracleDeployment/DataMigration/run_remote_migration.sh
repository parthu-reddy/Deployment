#!/bin/bash

# Configuration
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"
REMOTE_USER="ubuntu"
REMOTE_HOST="140.245.225.221"
COMPOSE_DIR="Food Delivery.nosync/Deployment"
SQL_FILE="migrate_ledger.sql"

echo "Copying migration script to remote server..."
scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SQL_FILE" "$REMOTE_USER@$REMOTE_HOST:~/$COMPOSE_DIR/"

echo "Running migration script..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
    "cd '$COMPOSE_DIR' && docker compose exec -T -u postgres postgres psql" < "$SQL_FILE"
    
if [ $? -eq 0 ]; then
    echo "Successfully migrated ledger data"
else
    echo "Error executing migration"
    exit 1
fi
