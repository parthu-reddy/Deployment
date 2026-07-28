# Generalized Microservice Deployment Instructions

This guide provides a comprehensive checklist and instructions for taking a newly created microservice and deploying it in the existing Food Delivery architecture on the Oracle environment using Docker Compose and Eureka.

## Prerequisites
- Your service should be built on Spring Boot.
- The service should be added to the parent `pom.xml` under `<modules>` if it's a Maven multi-module project.
- You must always deploy using the `dev` profile (`SPRING_PROFILES_ACTIVE=dev`) as per our deployment policy.

---

## Step 1: Create a Dockerfile
Every microservice needs a `Dockerfile` in its root folder to containerize the application.

Create `{ServiceName}/Dockerfile`:

```dockerfile
# Builder stage
FROM eclipse-temurin:17-jre-jammy as builder
WORKDIR /builder
COPY target/*.jar app.jar
RUN java -Djarmode=tools -jar app.jar extract --layers --launcher --destination extracted

# Final stage
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Non-root user setup for security
RUN useradd -m spring
USER spring

# Copy layers in order of frequency of change
COPY --from=builder /builder/extracted/dependencies/ ./
COPY --from=builder /builder/extracted/spring-boot-loader/ ./
COPY --from=builder /builder/extracted/snapshot-dependencies/ ./
COPY --from=builder /builder/extracted/application/ ./

ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"

# Update to match your service's port
EXPOSE <YOUR_PORT>
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
```

## Step 2: Configure Application Variables
Instead of putting your deployment variables in `application.yml`, you must create a `{service-name}.yml` inside the `Deployment` folder. This is picked up dynamically by the `ConfigService`.

Create `Deployment/{service-name}.yml`:

```yaml
spring:
  application:
    name: {service-name}
  datasource:
    url: ${DB_URL:jdbc:postgresql://postgres:5432/{service_db}}
    username: ${DB_USERNAME:postgres}
    password: ${DB_PASSWORD:password}
    driver-class-name: org.postgresql.Driver
    # Add Hikari connection pooling rules here
  flyway:
    enabled: true
    baseline-on-migrate: true
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS:kafka:29092}

eureka:
  client:
    service-url:
      defaultZone: ${EUREKA_URLS:http://eureka-server-1:8761/eureka/,http://eureka-server-2:8761/eureka/}
  instance:
    prefer-ip-address: true

server:
  port: <YOUR_PORT>
```

> [!TIP]
> Ensure your fallback `url` values point to internal Docker networks (e.g. `postgres:5432`) rather than `localhost`.

## Step 3: Add to docker-compose.yml
Update `Deployment/docker-compose.yml` to spin up your new service.

Add the following block under `services:`:

```yaml
  {service-name}:
    build:
      context: ../
      dockerfile: {ServiceName}/Dockerfile
    container_name: {service-name}
    ports:
      - <YOUR_PORT>:<YOUR_PORT>
    environment:
      - SPRING_PROFILES_ACTIVE=${SPRING_PROFILES_ACTIVE:-default}
      - CONFIG_SERVER_URL=http://${CONFIG_USER}:${CONFIG_PASSWORD}@config-service:8888
      - DB_URL=jdbc:postgresql://postgres:5432/{service_db}
      - DB_USERNAME=${POSTGRES_USER}
      - DB_PASSWORD=${POSTGRES_PASS}
      - KAFKA_BOOTSTRAP_SERVERS=kafka:29092
      - EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@eureka-server-1:8761/eureka/,http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@eureka-server-2:8761/eureka/
      - EUREKA_USER=${EUREKA_USER:-admin}
      - EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin}
      - SPRING_CONFIG_IMPORT=optional:configserver:http://${CONFIG_USER}:${CONFIG_PASSWORD}@config-service:8888
    depends_on:
      config-service:
        condition: service_healthy
      eureka-server-1:
        condition: service_healthy
      postgres:
        condition: service_healthy
      kafka: # (if applicable)
        condition: service_healthy
    restart: on-failure
```

## Step 4: Add Database to Initialization
If your service uses Postgres, you need to ensure the database is automatically created upon infra startup.

Modify `Deployment/init-multiple-dbs.sql`:
```sql
CREATE DATABASE {service_db};
```

## Step 5: Configure API Gateway Routing
If your service handles external requests from the UI or third-party webhooks, it must be routed via the API Gateway.

Modify `Deployment/api-gateway.yml` to add your route rules:

```yaml
        - id: {service-name}
          uri: lb://{service-name}
          predicates:
            - Path=/api/v1/{your_domain}/**
```

> [!NOTE]
> The `uri: lb://{service-name}` uses Eureka service discovery. The service name must exactly match `spring.application.name` in your `{service-name}.yml`.

## Step 6: Create an Individual Deploy Script
To deploy *just* your service without restarting the entire architecture, create an individual deployment shell script.

Create `Deployment/deploy_{ServiceName}.sh`:

```bash
#!/bin/bash
set -e

echo "Deploying {ServiceName}..."
cd ..

# Build Jar
mvn clean package -pl {ServiceName} -am -Pdev -DskipTests

# Deploy Container
cd Deployment
export SPRING_PROFILES_ACTIVE=dev
docker compose up --build -d {service-name}

echo "{ServiceName} deployed successfully."
```

Make it executable: `chmod +x deploy_{ServiceName}.sh`.

## Step 7: Complete Re-deployment
If you are deploying this for the very first time on a fresh VM, you can run the master script `OracleDeployment/03_deploy_dev.sh` which tears down and reconstructs everything.

---

## Troubleshooting & Common Mistakes

During deployment, you might encounter some common pitfalls. Always check this list before panicking:

1. **Duplicate Docker Compose Entries:**
   - **Error:** `yaml: construct errors: mapping key "<service-name>" already defined`
   - **Cause:** You accidentally added the service to `docker-compose.yml` when it was already defined somewhere else in the file (often at the very bottom).
   - **Fix:** Search the entire `docker-compose.yml` for your service name and ensure it only exists once. 

2. **Docker Daemon Not Running:**
   - **Error:** `failed to connect to the docker API at unix:///.../docker.sock`
   - **Cause:** The Docker daemon is not active on the host machine, or you are trying to run the deployment scripts locally instead of on the actual Oracle Cloud VM.
   - **Fix:** Ensure Docker is started (`sudo systemctl start docker` on Linux, or opening Docker Desktop on Mac). If deploying to Oracle, ensure you have successfully SSH'd into the remote VM before running `03_deploy_dev.sh`.

3. **Port Collisions:**
   - **Error:** `Bind for 0.0.0.0:<port> failed: port is already allocated.`
   - **Cause:** Another service is already using the port you assigned.
   - **Fix:** Double check the `EXPOSE` port in the `Dockerfile`, the `server.port` in your `{service-name}.yml`, and the `ports` mapping in `docker-compose.yml` to ensure they are unique across the architecture.

4. **Service Missing from Build (Not Compiling):**
   - **Error:** `Child module ... does not exist` during Maven build, or the Docker image fails to build because the JAR is missing.
   - **Cause:** You forgot to add the new microservice to the `<modules>` list in the root `pom.xml`.
   - **Fix:** Open the root `pom.xml` and ensure `<module>{ServiceName}</module>` is added.

5. **Rsync / File Transfer Issues with Spaces in Paths:**
   - **Error:** When syncing files to a remote VM, a service folder goes missing, or it creates a weird folder structure (e.g. creating `Food/` instead of `Food Delivery.nosync/`).
   - **Cause:** The destination path had spaces and wasn't properly quoted for the remote shell.
   - **Fix:** Make sure to quote the destination properly if it has spaces. For example: `rsync -avz ... user@host:"'Food Delivery.nosync/'"` (single quotes inside double quotes).
