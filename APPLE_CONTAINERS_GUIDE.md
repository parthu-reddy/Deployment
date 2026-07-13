# Apple Containers Integration

I have successfully added full orchestration support for Apple's native `container` CLI as a drop-in alternative to `docker-compose`. 

## What was changed

### 1. `apple-compose.sh` Orchestrator
I created [apple-compose.sh](file:///Users/parthureddy/Documents/Food Delivery/Deployment/apple-compose.sh). This script translates the functionality of `docker-compose.yml` into a format that the Apple `container` CLI can understand. 

It handles the key architectural difference of Apple Containers (one VM per container) by:
- Automatically detecting your Mac's host IP address on the local network (`en0`).
- Injecting this host IP into all Spring Boot and UI configurations (`KAFKA_BOOTSTRAP_SERVERS`, `DB_URL`, etc.).
- Binding the required ports of each service to the macOS host so the VMs can seamlessly communicate with each other through your host machine's networking layer.

### 2. `deploy.sh` Engine Support
I completely updated the main [deploy.sh](file:///Users/parthureddy/Documents/Food Delivery/Deployment/deploy.sh) script to support an engine flag. It now acts as a central router for your deployment.

- **To run using Docker (default):**
  Run `./deploy.sh` or `./deploy.sh --docker`. This will behave exactly as it did before, using `docker-compose`.

- **To run using Apple Containers:**
  Run `./deploy.sh --apple` (or `--container`). This will:
  1. Trigger `./apple-compose.sh down` to clean up existing Apple containers.
  2. Rebuild all your microservice images using `container build` by calling the `build_image.sh --apple` script inside each service directory.
  3. Sequentially orchestrate the startup of all 14 containers using `./apple-compose.sh up`, injecting the correct networking configurations.

You are now fully set up to test Apple's native containerization engine whenever you are ready!

### 3. Flyway Migration Fixes for Apple Containers

During the manual, sequential startup process, we identified a critical issue with Flyway database migrations that was preventing `customer-service` (and others) from booting correctly. 

Because we use a custom initialization script (`init-multiple-dbs.sql`) combined with PostGIS (which automatically initializes the `spatial_ref_sys` table in the `public` schema), Flyway was refusing to run migrations because the database schema was not completely empty, throwing this error:
`Found non-empty schema(s) "public" but no schema history table.`

**How it was fixed:**
I updated the Spring Boot YAML configurations for the microservices (`customer-service`, `restaurant-service`, `delivery-service`, `payment-service`) to explicitly instruct Flyway to handle this baseline scenario:
```yaml
flyway:
  enabled: true
  baseline-on-migrate: true
  baseline-version: "0"
```
This forces Flyway to create the schema history table even if tables exist, baseline at version `0`, and correctly execute the `V1__init_schema.sql` migrations.

## Current Status
Following your instructions, I have manually started every single container sequentially and validated their logs for at least 15-20 seconds to ensure a stable boot cycle and connection to Eureka/Kafka. **All containers have successfully started and registered without any errors.**

### To start the whole ecosystem quickly
You asked how to avoid recompiling when no code has changed. The `deploy.sh` script already has a `--skip-build` flag for this exact purpose!

To spin everything up using Apple Containers without rebuilding images, simply run:
```bash
./deploy.sh --apple --skip-build
```

You can view the progress directly in the terminal as the script will sequentially bring up the infrastructure followed by the services.
