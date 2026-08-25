#!/bin/bash
set -e

echo "=========================================================="
echo " Starting Food Delivery Architecture Deployment (DEV PROFILE)"
echo "=========================================================="

# Check if we are in the root directory
if [ ! -d "Deployment" ]; then
    echo "Error: 'Deployment' directory not found."
    echo "Make sure you run this script from the root of the cloned repository."
    exit 1
fi

echo "1. Configuring environment for OCI..."
PUBLIC_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "localhost")
echo "Detected Public IP: $PUBLIC_IP"

# Fix Nginx upstream to use the internal docker network hostname instead of a hardcoded local IP
sed -i "s/set \$upstream http:\/\/[0-9.]*:8080;/set \$upstream http:\/\/api-gateway:8080;/g" FoodDeliveryAppUI/nginx.conf

# Uncomment Docker DNS resolver in Nginx so it can resolve 'api-gateway'
sed -i "s/##resolver 127.0.0.11/resolver 127.0.0.11/g" FoodDeliveryAppUI/nginx.conf

# Add the public IP to ALLOWED_ORIGINS in .env if not already present
if ! grep -q "PLATFORM_BUSINESS_ZONE" Deployment/.env; then
    echo "PLATFORM_BUSINESS_ZONE=Asia/Kolkata" >> Deployment/.env
    echo "PLATFORM_DEFAULT_CURRENCY=INR" >> Deployment/.env
fi

if ! grep -q "http://$PUBLIC_IP" Deployment/.env; then
    sed -i "s|^ALLOWED_ORIGINS=.*|&,http://$PUBLIC_IP|g" Deployment/.env
fi

# Fix FSSAI API URL in docker-compose.yml to use the internal docker network hostname
sed -i "s|KYB_FSSAI_API_URL=http://localhost:8080/mock/fssai|KYB_FSSAI_API_URL=http://api-gateway:8080/mock/fssai|g" Deployment/docker-compose.yml

# SET THE DEV PROFILE VARIABLE
export SPRING_PROFILES_ACTIVE=dev
echo "Activated Spring Profile: $SPRING_PROFILES_ACTIVE"

echo "2. Starting Infrastructure Services (Postgres, Redis, Kafka, Zookeeper)..."
# Forcefully remove stray testcontainers (like test_pg) from failed integration tests
docker rm -f test_pg 2>/dev/null || true
cd Deployment
SPRING_PROFILES_ACTIVE=dev docker compose up -d zookeeper kafka postgres redis

echo "Waiting for infrastructure to initialize..."
# Wait for postgres to be fully ready
for i in {1..12}; do
  if docker compose exec -T -e PGPASSWORD=password postgres pg_isready -h 127.0.0.1 -U postgres; then
    echo "Postgres is ready."
    break
  fi
  echo "Waiting for Postgres..."
  sleep 10
done


echo "3. Building Java Microservices Natively (DEV Profile)..."
cd ..
mvn clean package -Pdev -Dmaven.test.skip=true

# Check if UI is available and install dependencies if package.json exists
if [ -d "FoodDeliveryAppUI" ]; then
    echo "4. Building React Frontend..."
    cd FoodDeliveryAppUI
    if [ -f "package.json" ]; then
        if ! command -v npm &> /dev/null; then
            echo "Installing Node.js and NPM..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi
        rm -rf node_modules package-lock.json
        npm install
        CI=false npm run build
    fi
    cd ..
fi

echo "5. Building and Starting Config and Eureka Containers sequentially..."
cd Deployment
for service in config-service eureka-server-1 eureka-server-2; do
    echo "Building $service..."
    SPRING_PROFILES_ACTIVE=dev docker compose build $service
    echo "Pruning dangling build cache to save space..."
    docker builder prune -a -f
    docker image prune -f
    SPRING_PROFILES_ACTIVE=dev docker compose up -d $service
done

echo "Waiting 20 seconds for config/eureka to boot up..."
sleep 20

# Start everything else in the main Deployment
echo "Building microservices sequentially to avoid exhausting disk space..."
SERVICES=$(docker compose config --services | grep -v -E 'zookeeper|kafka|postgres|redis|clickhouse|config-service|eureka-server-1|eureka-server-2|WARNING')
for service in $SERVICES; do
    echo "Building $service..."
    SPRING_PROFILES_ACTIVE=dev docker compose build $service
    echo "Pruning dangling build cache to save space..."
    docker builder prune -a -f
    docker image prune -f
done

echo "Starting all services..."
SPRING_PROFILES_ACTIVE=dev docker compose up -d


echo "=========================================================="
echo " DEV Deployment Complete! "
echo " Your UI should be available at: http://$PUBLIC_IP"
echo " Check the status of your containers using: docker ps"
echo " View logs of a specific service using: docker compose logs -f <service_name>"
echo "=========================================================="
