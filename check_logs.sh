#!/bin/bash
SSH_KEY="/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"
VM="ubuntu@140.245.234.137"
REMOTE="Food Delivery.nosync/Deployment"

echo "Fetching logs for all containers and scanning for errors..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$VM" "cd '$REMOTE' && docker compose logs --tail=500" > /tmp/deployment_logs.txt

echo "Scanning for exceptions and errors..."
grep -i -E "exception|error|failed|caused by|flyway|migration" /tmp/deployment_logs.txt > /tmp/deployment_errors.txt
echo "Errors found:"
cat /tmp/deployment_errors.txt | wc -l
