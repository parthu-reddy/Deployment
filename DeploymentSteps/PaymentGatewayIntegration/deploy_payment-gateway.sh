#!/bin/bash
set -e

ORACLE_IP="140.245.234.137"
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"

# Ensure script is run from the DeploymentSteps/PaymentGatewayIntegration directory or a valid relative path
cd "$(dirname "$0")"

echo "Syncing CommonLibrary..."
rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  ../../../CommonLibrary/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/CommonLibrary/"

echo "Syncing PaymentGatewayIntegration..."
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  ../../../PaymentGatewayIntegration/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/PaymentGatewayIntegration/"

echo "Building and restarting payment-gateway on remote..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$ORACLE_IP << 'EOF'
cd "Food Delivery.nosync"
# Rebuild common library first
mvn clean install -pl CommonLibrary -am -DskipTests
# Rebuild PaymentGatewayIntegration
mvn clean package -pl PaymentGatewayIntegration -am -Pdev -Dmaven.test.skip=true

cd Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose build --no-cache payment-gateway
docker compose up -d payment-gateway
EOF

echo "Deployment of payment-gateway complete!"
