#!/bin/bash
set -e

ORACLE_IP="140.245.225.221"
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"

# Ensure script is run from the DeploymentSteps directory or a valid relative path
cd "$(dirname "$0")"

echo "Syncing CommunicationIntegration..."
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' \
  ../../../CommunicationIntegration/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/CommunicationIntegration/"

echo "Building and restarting communication-integration on remote..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$ORACLE_IP << 'EOF'
cd "Food Delivery.nosync"
mvn clean package -pl CommunicationIntegration -am -Pdev -Dmaven.test.skip=true
cd Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose build --no-cache communication-integration
docker compose up -d communication-integration
EOF

echo "Deployment of communication-integration complete!"
