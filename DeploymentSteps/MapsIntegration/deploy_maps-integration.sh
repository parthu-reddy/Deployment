#!/bin/bash
set -e

ORACLE_IP="140.245.225.221"
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"

# Ensure script is run from the DeploymentSteps/MapsIntegration directory or a valid relative path
cd "$(dirname "$0")"

echo "Syncing CommonLibrary..."
rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  ../../../CommonLibrary/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/CommonLibrary/"

echo "Syncing MapsIntegration..."
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  ../../../MapsIntegration/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/MapsIntegration/"

echo "Building and restarting maps-integration on remote..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$ORACLE_IP << 'EOF'
cd "Food Delivery.nosync"
# Rebuild common library first
mvn clean install -pl CommonLibrary -am -DskipTests
# Rebuild MapsIntegration
mvn clean package -pl MapsIntegration -am -Pdev -Dmaven.test.skip=true

cd Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose build --no-cache maps-integration
docker compose up -d maps-integration
EOF

echo "Deployment of maps-integration complete!"
