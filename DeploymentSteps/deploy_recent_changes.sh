#!/bin/bash
set -e

ORACLE_IP="140.245.225.221"
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-07-17.key"

echo "Syncing changed microservices and CommonLibrary..."
rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  /Users/parthureddy/Documents/Food\ Delivery.nosync/CommonLibrary/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/CommonLibrary/"

rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  /Users/parthureddy/Documents/Food\ Delivery.nosync/CustomerApplication/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/CustomerApplication/"

rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  /Users/parthureddy/Documents/Food\ Delivery.nosync/DeliveryExecutiveApplication/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/DeliveryExecutiveApplication/"

rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  /Users/parthureddy/Documents/Food\ Delivery.nosync/RestaurantApplication/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/RestaurantApplication/"

rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  --exclude 'target' --exclude 'node_modules' --exclude '.git' \
  /Users/parthureddy/Documents/Food\ Delivery.nosync/FoodDeliveryAppUI/ \
  ubuntu@$ORACLE_IP:"~/Food\ Delivery.nosync/FoodDeliveryAppUI/"

echo "Building and restarting changed services on remote..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$ORACLE_IP << 'EOF'
cd "Food Delivery.nosync"
# Rebuild common library first
mvn clean install -pl CommonLibrary -am -DskipTests
# Rebuild changed services
mvn clean package -pl CustomerApplication,DeliveryExecutiveApplication,RestaurantApplication -am -Pdev -Dmaven.test.skip=true

cd Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose build --no-cache customer-service delivery-service restaurant-service
docker compose up -d customer-service delivery-service restaurant-service

cd ../FoodDeliveryAppUI
npm install
npm run build
npx pm2 restart all || npx pm2 start dist/server.cjs
EOF

echo "Deployment of changed services complete!"
