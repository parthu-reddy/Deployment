#!/bin/bash
set -e

PROJECT_ROOT="/Users/parthureddy/Documents/Food Delivery.nosync"

echo "======================================"
echo " Building Java Microservices..."
echo "======================================"
cd "$PROJECT_ROOT"
mvn clean package -DskipTests

echo "======================================"
echo " Building FoodDeliveryAppUI..."
echo "======================================"
cd "$PROJECT_ROOT/FoodDeliveryAppUI"
npm i
npm run build

echo "======================================"
echo " Building Apple Container Images..."
echo "======================================"
cd "$PROJECT_ROOT"
for service in ConfigService EurekaServer IdentityService CustomerApplication RestaurantApplication DeliveryExecutiveApplication PaymentGatewayIntegration MapsIntegration CommunicationIntegration ApiGateway FoodDeliveryAppUI; do
  echo "Building container image for $service..."
  cd "$PROJECT_ROOT/$service"
  ./build_image.sh --apple
done

echo "======================================"
echo " Deploying Apple Containers..."
echo "======================================"
cd "$PROJECT_ROOT/Deployment"
./apple-compose.sh down
./apple-compose.sh up

echo "======================================"
echo " Deployment Complete!"
echo "======================================"
