---
name: deployment-api
description: Reference guide for the Deployment configuration repository. Use this to understand the environment variables and shared configurations for the ecosystem.
---

# Deployment Configuration Reference

This repository is purely infrastructure and configuration. It does not expose APIs.

## Key Configurations

### Database Credentials
- `spring.datasource.url`: Typically points to `jdbc:postgresql://postgres:5432/food_delivery`
- Default User: `postgres`, Default Password: `postgres` (Overridden in `.env` for prod)

### Security Keys
- `jwt.secret`: Shared secret key used by `IdentityService` to sign JWTs, and `ApiGateway` to verify them. This key *must* be identical across both configurations.

### Infrastructure Ports
- PostgreSQL: `5432`
- Kafka: `9092`
- Zookeeper: `2181`
- Redis: `6379`
