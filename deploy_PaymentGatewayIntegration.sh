#!/bin/bash
set -e

# Parse args
ENGINE="docker"
SKIP_BUILD=false
for arg in "$@"; do
    if [ "$arg" == "--apple" ] || [ "$arg" == "--container" ]; then
        ENGINE="apple"
    elif [ "$arg" == "--docker" ]; then
        ENGINE="docker"
    elif [ "$arg" == "--skip-build" ]; then
        SKIP_BUILD=true
    fi
done

PROJECT_ROOT="/Users/parthureddy/Documents/Food Delivery"
DEPLOYMENT_DIR="$PROJECT_ROOT/Deployment"

SERVICE_DIR="PaymentGatewayIntegration"
CONTAINER_NAME="payment-gateway"

echo "======================================"
echo " Deploying $SERVICE_DIR..."
echo "======================================"

if [ "$SKIP_BUILD" = false ]; then
    echo "Building $SERVICE_DIR..."
    cd "$PROJECT_ROOT"
    mvn clean package -pl "$SERVICE_DIR" -am -DskipTests

    echo "Building image for $SERVICE_DIR..."
    cd "$DEPLOYMENT_DIR"
    if [ "$ENGINE" == "docker" ]; then
        docker-compose build "$CONTAINER_NAME"
    else
        (cd "$PROJECT_ROOT/$SERVICE_DIR" && ./build_image.sh --apple)
    fi
fi

echo "Starting $SERVICE_DIR..."
cd "$DEPLOYMENT_DIR"
if [ "$ENGINE" == "apple" ]; then
    ./apple-compose.sh up "$CONTAINER_NAME"
else
    docker-compose up -d "$CONTAINER_NAME"
fi

echo "======================================"
echo " $SERVICE_DIR Deployment Complete!"
echo "======================================"
