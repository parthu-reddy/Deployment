# Deployment Repository

This repository contains the infrastructure-as-code and configuration necessary to deploy the entire Food Delivery microservices ecosystem. It utilizes `docker-compose` for local development and testing.

## Setup & Run
1. Ensure Docker and Docker Compose are installed.
2. The `ConfigService` reads its properties from this repository. Ensure this repository is accessible or cloned locally, and the `ConfigService` is pointing to its path.
3. Start all services:
   ```bash
   docker-compose up -d
   ```
4. Stop all services:
   ```bash
   docker-compose down
   ```

## Key Infrastructure Components
- **Zookeeper & Kafka**: Message broker for asynchronous event-driven communication (e.g., `payment-events`, `order-events`).
- **PostgreSQL**: Relational database for core domain data (Orders, Users, Restaurants).
- **Redis**: In-memory data store for caching and temporary state (e.g., JWT blacklisting).
- **Service Configurations**: YAML files (e.g., `api-gateway.yml`, `customer-service.yml`) that are served by the `ConfigService`.
