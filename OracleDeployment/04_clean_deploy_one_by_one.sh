#!/bin/bash
set -e

echo "=========================================================="
echo " Starting Sequential Food Delivery Deployment (DEV PROFILE)"
echo "=========================================================="

if [ ! -d "Deployment" ]; then
    echo "Error: 'Deployment' directory not found."
    echo "Make sure you run this script from the root of the cloned repository."
    exit 1
fi

echo "1. Configuring environment for OCI..."
PUBLIC_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "localhost")
echo "Detected Public IP: $PUBLIC_IP"

sed -i "s/set \$upstream http:\/\/[0-9.]*:8080;/set \$upstream http:\/\/api-gateway:8080;/g" FoodDeliveryAppUI/nginx.conf
sed -i "s/##resolver 127.0.0.11/resolver 127.0.0.11/g" FoodDeliveryAppUI/nginx.conf

if ! grep -q "http://$PUBLIC_IP" Deployment/.env; then
    sed -i "s|^ALLOWED_ORIGINS=.*|&,http://$PUBLIC_IP|g" Deployment/.env
fi
sed -i "s|KYB_FSSAI_API_URL=http://localhost:8080/mock/fssai|KYB_FSSAI_API_URL=http://api-gateway:8080/mock/fssai|g" Deployment/docker-compose.yml

export SPRING_PROFILES_ACTIVE=dev

echo "2. Cleaning up Docker Environment completely..."
cd Deployment
docker compose down -v
echo "Running system prune to clear out old containers and images..."
docker system prune -af
docker rm -f test_pg 2>/dev/null || true

echo "3. Starting Infrastructure Services (Postgres, Redis, Kafka, Zookeeper, Clickhouse)..."
SPRING_PROFILES_ACTIVE=dev docker compose up -d zookeeper kafka postgres redis clickhouse

echo "Waiting for Postgres to initialize..."
for i in {1..12}; do
  if docker compose exec -T -e PGPASSWORD=password postgres pg_isready -h 127.0.0.1 -U postgres; then
    echo "Postgres is ready."
    break
  fi
  echo "Waiting for Postgres..."
  sleep 10
done

echo "4. Building Java Microservices Natively (DEV Profile)..."
cd ..
mvn clean package -Pdev -Dmaven.test.skip=true

if [ -d "FoodDeliveryAppUI" ]; then
    echo "5. Building React Frontend..."
    cd FoodDeliveryAppUI
    if [ -f "package.json" ]; then
        if ! command -v npm &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi
        rm -rf node_modules package-lock.json
        npm install
        CI=false npm run build
    fi
    cd ..
fi

echo "6. Starting Core Services (Config, Eureka)..."
cd Deployment
SPRING_PROFILES_ACTIVE=dev docker compose up --build -d config-service eureka-server-1 eureka-server-2

echo "Waiting 30 seconds for config/eureka to boot up..."
sleep 30

echo "7. Starting Microservices One by One..."

SERVICES=(
    "api-gateway"
    "customer-service"
    "restaurant-service"
    "delivery-service"
    "payment-gateway"
    "maps-integration"
    "communication-integration"
    "identity-service"
    "government-id-service"
    "ledger-service"
    "chat-service"
    "ondc-integration-service"
    "wallet-service"
    "campaign-service"
    "bidding-engine"
    "budget-pacing-service"
    "event-tracking-service"
    "food-delivery-app-ui"
)

for SERVICE in "${SERVICES[@]}"; do
    echo "----------------------------------------"
    echo " Starting $SERVICE..."
    SPRING_PROFILES_ACTIVE=dev docker compose up --build -d "$SERVICE"
    echo "Waiting 20 seconds for $SERVICE to initialize..."
    sleep 20
    
    # Check if container is running
    STATUS=$(docker inspect -f '{{.State.Status}}' "$SERVICE" 2>/dev/null || echo "not-found")
    if [ "$STATUS" != "running" ]; then
        echo "WARNING: $SERVICE state is $STATUS (expected running). Fetching logs..."
        docker compose logs --tail=50 "$SERVICE"
    else
        echo "$SERVICE appears to be running successfully."
    fi
done

echo "=========================================================="
echo " Sequential DEV Deployment Complete! "
echo " Your UI should be available at: http://$PUBLIC_IP"
echo " Use 'docker ps' to check running containers."
echo "=========================================================="
