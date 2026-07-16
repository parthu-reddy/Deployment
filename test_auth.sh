#!/bin/bash
curl -s -X POST "http://localhost:8080/api/v1/internal/auth/initiate?phoneNumber=1234567899" -H "X-Calling-Service: DELIVERY"
echo ""
OTP=$(container exec shared_redis redis-cli get OTP:1234567899:delivery | tr -d '\r')
echo "OTP: $OTP"
RESP=$(curl -s -X POST "http://localhost:8080/api/v1/internal/auth/verify?phoneNumber=1234567899&otp=$OTP" -H "X-Calling-Service: DELIVERY")
echo "$RESP"
TOKEN=$(echo "$RESP" | grep -o '"data":"[^"]*' | cut -d'"' -f4)
echo "Token: $TOKEN"
echo "Requesting via API Gateway..."
curl -s -v "http://localhost:8080/api/delivery/profile?phoneNumber=1234567899" -H "Authorization: Bearer $TOKEN"
