#!/bin/bash
set -e

PROJECT_ROOT="/Users/parthureddy/Documents/Food Delivery.nosync"
cd "$PROJECT_ROOT"

# Available services
JAVA_SERVICES=(ConfigService EurekaServer IdentityService CustomerApplication RestaurantApplication DeliveryExecutiveApplication PaymentGatewayIntegration MapsIntegration CommunicationIntegration ApiGateway)
UI_SERVICE="FoodDeliveryAppUI"

TARGET_SERVICES=("$@")
CHANGED_JAVA_SERVICES=()
BUILD_UI=false

echo "======================================"
echo " Detecting Changed Services..."
echo "======================================"

if [ ${#TARGET_SERVICES[@]} -eq 0 ]; then
    for service in "${JAVA_SERVICES[@]}"; do
        if [ ! -d "$service/target" ]; then
            CHANGED_JAVA_SERVICES+=("$service")
            echo "Detected missing target for $service"
        else
            # Check if any file in src or pom.xml is newer than the jar
            NEWER=$(find "$service/src" "$service/pom.xml" -newer "$service/target/"*.jar 2>/dev/null | head -n 1)
            if [ ! -z "$NEWER" ]; then
                CHANGED_JAVA_SERVICES+=("$service")
                echo "Detected changes in $service"
            fi
        fi
    done
    
    if [ ! -d "$UI_SERVICE/dist" ]; then
        BUILD_UI=true
        echo "Detected missing dist for $UI_SERVICE"
    else
        NEWER=$(find "$UI_SERVICE/src" "$UI_SERVICE/public" "$UI_SERVICE/package.json" "$UI_SERVICE/vite.config.ts" "$UI_SERVICE/index.html" -newer "$UI_SERVICE/dist/" 2>/dev/null | head -n 1)
        if [ ! -z "$NEWER" ]; then
            BUILD_UI=true
            echo "Detected changes in $UI_SERVICE"
        fi
    fi
else
    # User provided specific services
    for target in "${TARGET_SERVICES[@]}"; do
        if [ "$target" == "$UI_SERVICE" ] || [ "$target" == "food-delivery-app-ui" ]; then
            BUILD_UI=true
        else
            CHANGED_JAVA_SERVICES+=("$target")
        fi
    done
fi

if [ ${#CHANGED_JAVA_SERVICES[@]} -eq 0 ] && [ "$BUILD_UI" = false ]; then
    echo "No changes detected. Everything is up to date!"
    exit 0
fi

if [ ${#CHANGED_JAVA_SERVICES[@]} -gt 0 ]; then
    echo "======================================"
    echo " Building Java Microservices..."
    echo "======================================"
    MODULES=$(IFS=, ; echo "${CHANGED_JAVA_SERVICES[*]}")
    # Always include CommonLibrary if we build any Java service
    mvn clean package -pl "$MODULES",CommonLibrary -am -DskipTests -T 1C
fi

if [ "$BUILD_UI" = true ]; then
    echo "======================================"
    echo " Building FoodDeliveryAppUI..."
    echo "======================================"
    cd "$PROJECT_ROOT/FoodDeliveryAppUI"
    npm i --cache .npm-cache
    npm run build
    cd "$PROJECT_ROOT"
fi

echo "======================================"
echo " Building Apple Container Images..."
echo "======================================"
# Build images for changed java services
for service in "${CHANGED_JAVA_SERVICES[@]}"; do
    echo "Building container image for $service..."
    cd "$PROJECT_ROOT/$service"
    ./build_image.sh --apple
done

# Build UI image if needed
if [ "$BUILD_UI" = true ]; then
    echo "Building container image for $UI_SERVICE..."
    cd "$PROJECT_ROOT/$UI_SERVICE"
    ./build_image.sh --apple
fi

echo "======================================"
echo " Deploying Apple Containers..."
echo "======================================"
cd "$PROJECT_ROOT/Deployment"

# We need to map service directories to container names for compose
CONTAINERS=()
for service in "${CHANGED_JAVA_SERVICES[@]}"; do
    case "$service" in
        "ConfigService") CONTAINERS+=("config-service") ;;
        "EurekaServer") CONTAINERS+=("eureka-server-1") ;;
        "IdentityService") CONTAINERS+=("identity-service") ;;
        "CustomerApplication") CONTAINERS+=("customer-service") ;;
        "RestaurantApplication") CONTAINERS+=("restaurant-service") ;;
        "DeliveryExecutiveApplication") CONTAINERS+=("delivery-service") ;;
        "PaymentGatewayIntegration") CONTAINERS+=("payment-gateway") ;;
        "MapsIntegration") CONTAINERS+=("maps-integration") ;;
        "CommunicationIntegration") CONTAINERS+=("communication-integration") ;;
        "ApiGateway") CONTAINERS+=("api-gateway") ;;
        *) CONTAINERS+=("$service") ;;
    esac
done

if [ "$BUILD_UI" = true ]; then
    CONTAINERS+=("food-delivery-app-ui")
fi

# Bring down specific containers and bring them back up
echo "Restarting containers: ${CONTAINERS[*]}"
./apple-compose.sh up

echo "======================================"
echo " Deployment Complete!"
echo "======================================"
