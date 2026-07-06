---
name: understand-deployment
description: Troubleshooting guide and architectural overview for the Deployment repository. Use this skill when investigating infrastructure or environment configuration issues.
---

# Understand Deployment

The Deployment repository centralizes the state of the infrastructure and the configuration for the microservices.

## Architecture

- **Docker Compose**: The `docker-compose.yml` file acts as the single source of truth for the local development environment, spinning up all necessary backing services (Kafka, Postgres, Redis) and the microservices themselves.
- **Config Repository**: The `ConfigService` is configured to read the YAML files stored in this repository. Changes committed to this repository are picked up by the ConfigService and served to the applications.

## Troubleshooting

- **Service Connection Refused**: If a service cannot connect to Postgres or Kafka, ensure the `docker-compose` stack is fully up and running. Some services might start before Kafka is fully initialized, causing connection drops on boot.
- **Config Not Updating**: If you change `customer-service.yml` but the application doesn't reflect the changes, ensure you have committed the changes (if ConfigService is reading from Git) or triggered a `/actuator/refresh` on the specific microservice.
