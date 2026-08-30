#!/bin/bash
set -e

ORACLE_IP="140.245.234.137"
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"

# Ensure script is run from the DeploymentSteps/CommunicationIntegration directory or a valid relative path
cd "$(dirname "$0")"

echo "Syncing CommonLibrary..."
rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  ../../../../CommonLibrary/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/CommonLibrary/"

echo "Syncing CommunicationIntegration..."
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  ../../../../CommunicationIntegration/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/CommunicationIntegration/"

echo "Building and restarting communication-service on remote..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$ORACLE_IP << 'EOF'
cd "Food Delivery.nosync"
# Rebuild common library first
mvn clean install -pl CommonLibrary -am -DskipTests </dev/null
# Rebuild CommunicationIntegration
mvn clean package -pl CommunicationIntegration -am -Pdev -Dmaven.test.skip=true </dev/null

cd Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose build --no-cache communication-service
docker compose up -d communication-service
EOF

echo "Deployment of communication-service complete!"
