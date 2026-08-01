#!/bin/bash
set -e

echo "Deploying CommunicationService..."
cd ..

# Build Jar
mvn clean package -pl CommunicationService -am -Pdev -Dmaven.test.skip=true

# Deploy Container
cd Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose up --build -d chat-service

echo "CommunicationService deployed successfully."
