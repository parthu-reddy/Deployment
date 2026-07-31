#!/bin/bash
set -e

ORACLE_IP="140.245.225.221"
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"

# Ensure script is run from the DeploymentSteps directory or a valid relative path
cd "$(dirname "$0")"

echo "Syncing DeliveryExecutiveApplication..."
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' \
  ../../../DeliveryExecutiveApplication/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/DeliveryExecutiveApplication/"

echo "Building and restarting delivery-service on remote..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$ORACLE_IP << 'EOF'
cd "Food Delivery.nosync"
mvn clean package -pl DeliveryExecutiveApplication -am -Pdev -Dmaven.test.skip=true
cd Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose build --no-cache delivery-service
docker compose up -d delivery-service
EOF

echo "Deployment of delivery-service complete!"
