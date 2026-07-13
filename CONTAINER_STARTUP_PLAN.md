# Food Delivery Application - Container Startup Plan

This document outlines the required startup sequence for the microservices and infrastructure components in this deployment. The sequence ensures that all dependent services (such as databases, message brokers, and discovery servers) are fully initialized and healthy before downstream applications attempt to connect to them.

## 1. Infrastructure Layer (Level 1)
These components have no upstream dependencies and must be started first.
- **zookeeper** (`shared_zookeeper`): Required for Kafka broker coordination.
- **postgres** (`shared_postgres`): The primary relational database for microservices.
- **redis** (`shared_redis`): The caching and temporary data store.

## 2. Infrastructure Layer (Level 2)
- **kafka** (`shared_kafka`): Depends on `zookeeper`. Must wait for Zookeeper to be fully healthy before starting.

## 3. Core Platform Services
These services provide configuration and service discovery to all business microservices. They should be started and healthy before any application services boot up.
- **config-service**: Provides centralized configuration to all microservices.
- **eureka-server-1**: The service registry. Microservices register here upon startup.

## 4. Business Microservices Layer
All services in this layer depend heavily on the Infrastructure and Core Platform layers (Postgres, Kafka, Redis, Config Service, and Eureka). They can be started in parallel once the layers above are healthy.
- **identity-service**: Manages user authentication and roles.
- **restaurant-service**: Manages restaurant onboarding and catalog.
- **delivery-service**: Manages delivery executive onboarding and tracking.
- **customer-service**: Manages customer profiles and order placement.
- **payment-gateway**: Manages integrations with third-party payment providers.
- **maps-integration**: Manages location and routing integrations.
- **communication-integration**: Listens to Kafka events and dispatches notifications.

## 5. Edge Layer
- **api-gateway**: Depends on `config-service` and `eureka-server-1`. Routes external traffic to the internal business microservices. Must be started after Eureka is healthy so it can fetch the routing registry.

## 6. Frontend Layer
- **food-delivery-app-ui**: The React/Vite frontend. Depends on `api-gateway`. Should be started last as it routes its API calls through the gateway.

## Automated Startup
Because the `docker-compose.yml` is configured with `depends_on: condition: service_healthy`, you can simply run:
```bash
docker-compose up -d
```
Docker Compose will automatically enforce this exact startup sequence based on the health checks defined for each service.
