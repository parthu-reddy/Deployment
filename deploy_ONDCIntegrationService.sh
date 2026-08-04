#!/bin/bash

# Configuration
SERVICE_NAME="ondc-integration-service"
IMAGE_NAME="parthureddy/ondc-integration-service"
IMAGE_TAG="latest"
PORT=8095
NETWORK="food-delivery-network"

# Build the jar
cd ../ONDCIntegrationService
echo "Building $SERVICE_NAME..."
mvn clean package -DskipTests

# Build the docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME:$IMAGE_TAG .

# Stop and remove existing container
echo "Stopping existing container..."
docker stop $SERVICE_NAME || true
docker rm $SERVICE_NAME || true

# Run the new container
echo "Starting new container..."
docker run -d \
  --name $SERVICE_NAME \
  --network $NETWORK \
  -p $PORT:$PORT \
  -e SPRING_PROFILES_ACTIVE=dev \
  -e EUREKA_URL=http://eureka-server:8761/eureka \
  $IMAGE_NAME:$IMAGE_TAG

echo "Deployment complete! Service is running on port $PORT"
