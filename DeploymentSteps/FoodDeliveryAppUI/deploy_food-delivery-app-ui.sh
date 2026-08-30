#!/bin/bash
set -e

ORACLE_IP="140.245.234.137"
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"

cd "$(dirname "$0")"

echo "Syncing FoodDeliveryAppUI..."
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'node_modules' --exclude 'dist' \
  ../../../FoodDeliveryAppUI/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/FoodDeliveryAppUI/"

echo "Building and restarting food-delivery-app-ui on remote..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$ORACLE_IP << 'EOF'
cd "Food Delivery.nosync/FoodDeliveryAppUI"
npm run build </dev/null
cd ../Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose build --no-cache food-delivery-app-ui
docker compose up -d food-delivery-app-ui
EOF

echo "Deployment of food-delivery-app-ui complete!"
