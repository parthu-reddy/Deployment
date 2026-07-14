#!/bin/bash
set -e

# Parse args
ENGINE="docker"
for arg in "$@"; do
    if [ "$arg" == "--apple" ] || [ "$arg" == "--container" ]; then
        ENGINE="apple"
    elif [ "$arg" == "--docker" ]; then
        ENGINE="docker"
    fi
done

PROJECT_ROOT="/Users/parthureddy/Documents/Food Delivery.nosync"
DEPLOYMENT_DIR="$PROJECT_ROOT/Deployment"

echo "======================================"
echo " Deploying Infrastructure..."
echo "======================================"

cd "$DEPLOYMENT_DIR"

if [ "$ENGINE" == "apple" ]; then
    ./apple-compose.sh up infra
else
    # Start in specific order
    INFRA_SERVICES=("zookeeper" "postgres" "redis" "kafka")
    
    for service in "${INFRA_SERVICES[@]}"; do
        echo "Starting $service..."
        docker-compose up -d "$service"
    done
fi

echo "======================================"
echo " Infrastructure Deployment Complete!"
echo "======================================"
