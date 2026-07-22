# Dummy Data Execution & Initialization Guide

To properly initialize all dummy data directly on the Oracle DB server, you need to follow a specific sequence. This sequence ensures that the databases are wiped cleanly, schemas are rebuilt by the microservices, data is generated freshly, and then inserted in the correct order to satisfy foreign key constraints across microservices.

## Master Initialization Script

You can run the following bash script directly on your Oracle server (inside the directory containing your `docker-compose.yml`). This script will automatically reset the databases, rebuild schemas, generate fresh dummy data, and insert it in the correct execution order.

Save this as `init_dummy_data.sh` and run it with `bash init_dummy_data.sh`:

```bash
#!/bin/bash

# Configuration
DB_PASS="***REMOVED***"

echo "=========================================="
echo "1. Stopping microservices to release DB connections..."
echo "=========================================="
docker compose stop customer-service restaurant-service delivery-service identity-service

echo "=========================================="
echo "2. Wiping databases cleanly..."
echo "=========================================="
for db in identity_db restaurant_db food_delivery delivery_db; do
    echo "Wiping database $db..."
    docker compose exec -T -e PGPASSWORD=$DB_PASS postgres psql -h 127.0.0.1 -U postgres -d $db -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
done

echo "Creating postgis extension in restaurant_db..."
docker compose exec -T -e PGPASSWORD=$DB_PASS postgres psql -h 127.0.0.1 -U postgres -d restaurant_db -c 'CREATE EXTENSION IF NOT EXISTS postgis;'

echo "=========================================="
echo "3. Restarting microservices to rebuild schemas..."
echo "=========================================="
docker compose start identity-service restaurant-service customer-service delivery-service

echo "Waiting 60 seconds for Spring Boot services to fully boot up and generate their database schemas..."
sleep 60

echo "=========================================="
echo "4. Generating fresh SQL dummy data..."
echo "=========================================="
# Run the python scripts to generate the SQL files
python3 generate_dummy_data.py
python3 generate_users_dummy_data.py

# Helper function to run a SQL file
run_sql() {
    local db_name=$1
    local sql_file=$2
    
    echo "Running $sql_file on database $db_name..."
    docker compose exec -T -e PGPASSWORD=$DB_PASS postgres psql -h 127.0.0.1 -U postgres -d $db_name < "$sql_file"
        
    if [ $? -eq 0 ]; then
        echo "Successfully executed $sql_file on $db_name"
    else
        echo "Error executing $sql_file on $db_name"
        exit 1
    fi
}

echo "=========================================="
echo "5. Inserting dummy data in strict order..."
echo "=========================================="

# 5.1 Identity DB (MUST BE FIRST)
run_sql "identity_db" "dummy_identity_data.sql"
run_sql "identity_db" "dummy_riders_customers_identity.sql"

# 5.2 Restaurant DB
run_sql "restaurant_db" "dummy_data.sql"

# 5.3 Customer DB (Uses the food_delivery database)
run_sql "food_delivery" "dummy_customers.sql"
run_sql "food_delivery" "dummy_customer_data.sql"

# 5.4 Delivery DB
run_sql "delivery_db" "dummy_riders.sql"
run_sql "delivery_db" "dummy_delivery_data.sql"

echo "=========================================="
echo "Dummy data successfully initialized!"
echo "You can now run 'python3 remote_rider_simulator.py' to populate Redis locations and keep drivers online."
echo "=========================================="
```

### Execution Order Breakdown

If you are running the SQL files manually via `docker compose exec`, you **must** execute them in this exact order:

1. **Identity Database (`identity_db`)**
   The Identity Service database must be populated first so that the user IDs exist when the other databases try to reference them (as `owner_id`, `customer_id`, `user_id`, etc).
   - `dummy_identity_data.sql`
   - `dummy_riders_customers_identity.sql`

2. **Restaurant Database (`restaurant_db`)**
   Populate the restaurants, outlets, and menu items. 
   *(Requires `postgis` extension to be active).*
   - `dummy_data.sql`

3. **Customer Database (`food_delivery`)**
   Populate customer profiles and saved addresses.
   - `dummy_customers.sql`
   - `dummy_customer_data.sql`

4. **Delivery Database (`delivery_db`)**
   Populate delivery executive profiles and statuses.
   - `dummy_riders.sql`
   - `dummy_delivery_data.sql`

5. **Redis Tracking & Status**
   Run `remote_rider_simulator.py` to continuously populate Redis with the driver locations and keep them online.
