#!/bin/bash
set -e

echo "Deploying LedgerService..."

# Move to the root directory
cd ..

# Build the LedgerService jar using the dev profile
echo "Building LedgerService jar..."
mvn clean package -pl LedgerService -am -Pdev -DskipTests

# Move back to deployment directory
cd Deployment

# Deploy the docker container
echo "Starting LedgerService container..."
export SPRING_PROFILES_ACTIVE=dev
docker compose up --build -d ledger-service

echo "LedgerService deployed successfully."
