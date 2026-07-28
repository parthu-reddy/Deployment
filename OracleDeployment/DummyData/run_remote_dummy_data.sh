#!/bin/bash

# Configuration
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"
REMOTE_USER="ubuntu"
REMOTE_HOST="140.245.225.221"
DB_PASS="password"
COMPOSE_DIR="Food Delivery.nosync/Deployment"

# Helper function to run a SQL file against a specific remote database
run_sql() {
    local db_name=$1
    local sql_file=$2
    
    echo "Running $sql_file on remote database $db_name..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
        "cd '$COMPOSE_DIR' && docker compose exec -T -u postgres postgres psql -d $db_name" < "$sql_file"
        
    if [ $? -eq 0 ]; then
        echo "Successfully executed $sql_file on $db_name"
    else
        echo "Error executing $sql_file on $db_name"
        exit 1
    fi
}

echo "Starting remote dummy data insertion..."

# 1. Identity DB (MUST BE FIRST)
run_sql "identity_db" "dummy_riders_customers_identity.sql"
run_sql "identity_db" "dummy_identity_data.sql"

# 2. Customer DB (Uses the food_delivery database)
run_sql "food_delivery" "dummy_customers.sql"
run_sql "food_delivery" "dummy_customer_data.sql"

# 3. Delivery DB
run_sql "delivery_db" "dummy_riders.sql"
run_sql "delivery_db" "dummy_delivery_data.sql"

# 4. Restaurant DB
run_sql "restaurant_db" "dummy_data.sql"

# 5. Government ID DB
run_sql "government_id_db" "dummy_government_id_brands.sql"
run_sql "government_id_db" "dummy_government_id_executives.sql"

echo "Dummy data successfully inserted into remote databases!"
