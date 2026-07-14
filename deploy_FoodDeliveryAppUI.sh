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

PROJECT_ROOT="/Users/parthureddy/Documents/Food Delivery.nosync"
DEPLOYMENT_DIR="$PROJECT_ROOT/Deployment"

SERVICE_DIR="FoodDeliveryAppUI"
CONTAINER_NAME="food-delivery-app-ui"

echo "======================================"
echo " Deploying $SERVICE_DIR..."
echo "======================================"

if [ "$SKIP_BUILD" = false ]; then
    echo "Building UI assets for $SERVICE_DIR..."
    cd "$PROJECT_ROOT/$SERVICE_DIR"
    npm install
    npm run build

    echo "Building image for $SERVICE_DIR..."
    
    # Specific logic for UI deployment (apple requires nginx.conf rewrite for host IP)
    if [ "$ENGINE" == "apple" ]; then
        HOST_IP=$(ipconfig getifaddr en0 || echo "127.0.0.1")
        cp "$PROJECT_ROOT/$SERVICE_DIR/nginx.conf" "$PROJECT_ROOT/$SERVICE_DIR/nginx.conf.bak"
        
        # Replace dns resolver and gateway url
        sed -i.tmp -e 's/resolver 127.0.0.11/#resolver 127.0.0.11/g' \
            -e "s|http://api-gateway:8080|http://$HOST_IP:8080|g" \
            "$PROJECT_ROOT/$SERVICE_DIR/nginx.conf"
            
        rm -f "$PROJECT_ROOT/$SERVICE_DIR/nginx.conf.tmp"
        
        (cd "$PROJECT_ROOT/$SERVICE_DIR" && ./build_image.sh --apple)
        
        # Restore nginx config
        mv "$PROJECT_ROOT/$SERVICE_DIR/nginx.conf.bak" "$PROJECT_ROOT/$SERVICE_DIR/nginx.conf"
    else
        cd "$DEPLOYMENT_DIR"
        docker-compose build "$CONTAINER_NAME"
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
