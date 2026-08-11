#!/bin/bash
set -e

ORACLE_IP="140.245.225.221"
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"

# Ensure script is run from the DeploymentSteps/ApiGateway directory or a valid relative path
cd "$(dirname "$0")"

echo "Syncing CommonLibrary..."
rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  ../../../CommonLibrary/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/CommonLibrary/"

echo "Syncing ApiGateway..."
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  ../../../ApiGateway/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/ApiGateway/"

echo "Building and restarting api-gateway on remote..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$ORACLE_IP << 'EOF'
cd "Food Delivery.nosync"
# Rebuild common library first
mvn clean install -pl CommonLibrary -am -DskipTests
# Rebuild ApiGateway
mvn clean package -pl ApiGateway -am -Pdev -Dmaven.test.skip=true

cd Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose build --no-cache api-gateway
docker compose up -d api-gateway
EOF

echo "Deployment of api-gateway complete!"
