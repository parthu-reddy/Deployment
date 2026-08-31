# Generalized Microservice Deployment Instructions

This guide covers taking a new microservice from nothing to running on the Oracle VM.

## How deployment works

The VM builds nothing. Its copy of the workspace contains only `Deployment/` — no source, no jars.

    build (Mac or CI)  ->  publish.sh  ->  OCIR  ->  deploy.sh  ->  VM pulls and runs

**Two different delivery paths, and mixing them up wastes hours:**

| What | How it reaches the VM | To change it |
|---|---|---|
| Application code | Baked into an image, tagged with its git sha, pulled from OCIR | `publish.sh` then `deploy.sh` |
| Config YAML (`Deployment/*.yml`) | Bind-mounted from the VM's `Deployment/` directory into `config-service` at `/config` | rsync `Deployment/`, then restart the readers |

`config-service` runs with `SPRING_PROFILES_ACTIVE=native` and
`SPRING_CLOUD_CONFIG_SERVER_NATIVE_SEARCH_LOCATIONS=file:/config`, so it serves whatever YAML is on
the VM's disk. A new image will **not** pick up a config change, and rsyncing config will not
change any code.

## Prerequisites

- Spring Boot, with `spring-cloud-starter-netflix-eureka-client` in its `pom.xml`.
- Registered in the root aggregator `pom.xml` under `<modules>`.
- Registered in `Deployment/service-map.tsv` — `publish.sh` and `deploy.sh` both refuse a service
  that is not listed there, and it is the only place the build context is recorded.
- The `dev` profile is already active: `SPRING_PROFILES_ACTIVE=dev` lives in the VM's `.env` and
  compose defaults to it. Do not set it per-deploy.

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

> [!WARNING]
> `config-service` bind-mounts the VM's `Deployment/` directory at `/config`. Adding or editing
> `{service-name}.yml` or `api-gateway.yml` therefore requires syncing that directory to the VM and
> restarting the services that read it. Redeploying the image does nothing for a config change.
>
> ```bash
> rsync -avz -e "ssh -i $SSH_KEY" --exclude '.env' --exclude 'node_modules' --exclude '__pycache__' \
>   "Deployment/" ubuntu@140.245.234.137:"/home/ubuntu/Food Delivery.nosync/Deployment/"
> ssh -i "$SSH_KEY" ubuntu@140.245.234.137 \
>   "cd 'Food Delivery.nosync/Deployment' && docker compose restart config-service {service-name}"
> ```
>
> **Quote the remote path so the REMOTE shell cannot split it.** This was hit again on 2026-08-31:
> `rsync ... ubuntu@host:"/home/ubuntu/Food Delivery.nosync/Deployment/api-gateway.yml"` **exited 0
> and wrote nothing** — the shell stripped the quotes, the remote shell split on the space, and the
> file landed at `/home/ubuntu/Food`. macOS ships rsync 2.6.9, which has **no `--protect-args`/`-s`**.
> The form that works, verified by matching md5 on both ends:
>
> ```bash
> rsync -az -e "ssh -i $SSH_KEY" Deployment/api-gateway.yml \
>   'ubuntu@140.245.234.137:/home/ubuntu/Food\ Delivery.nosync/Deployment/api-gateway.yml'
> ```
>
> Single quotes locally, backslash-escaped space for the remote shell. **Always compare checksums
> afterwards** — the exit code is 0 either way.
>
> `.env` is excluded on purpose — it holds live credentials and is written on the VM by
> `fetch_secrets_from_vault.sh`. Overwriting it from here reintroduces plaintext secrets on a laptop.

## Step 6: Register the service so it can be published

There are no per-service deploy scripts any more. `Deployment/deploy_{ServiceName}.sh` used to run
`mvn clean package` and `docker compose up --build` on the VM; neither is possible now.

Add one tab-separated row to `Deployment/service-map.tsv`:

```
{ServiceName}	{service-name}	..	{ServiceName}/Dockerfile
```

The columns are module directory, compose service name, **build context**, and Dockerfile path.
None of it is derivable, which is why the file exists:

- `CommunicationService` -> `chat-service`, `UserTrackingService` -> `event-tracking-service`;
  the directory name does not predict the service name.
- Java services build with the workspace root (`..`) as context because their Dockerfiles do
  `COPY {Module}/target/*.jar`. The UI builds with its **own** directory as context because its
  Dockerfile does `COPY nginx.conf`. Assuming one context for everything broke a publish 11 images
  in.

Then:

```bash
export REGISTRY=hyd.ocir.io/axekmbadoczl
mvn package -pl {ServiceName} -am -DskipTests   # a jar must exist; publish.sh rejects a stale one
Deployment/publish.sh {service-name}
Deployment/deploy.sh {service-name}
```

`publish.sh` tags by git sha (never `latest`), records the tag in `Deployment/.versions`, and
refuses to publish a jar older than its sources. `deploy.sh` pulls, starts, waits for health, and
then verifies the container actually ended up on the intended image — a deploy that silently
changes nothing still reports healthy without that check.

## Step 7: Full deployment

```bash
Deployment/OracleDeployment/03_clean_deploy.sh          # --wipe also destroys volumes
```

Run it from the workspace root on your Mac. It syncs the image tags into the VM's `.env`, starts
infrastructure, waits for Postgres, deploys config and discovery first and the remaining services
second, then reconciles declared against running.

Related:

- `Deployment/deploy.sh --rollback {service-name}` — previous tag, refused across a destructive
  migration or a missing image.
- `Deployment/reconcile.sh` — declared vs running, plus image drift. Removes only with `--apply`.
- `Deployment/SCHEMA_POLICY.md` — migrations are immutable and forward-only.

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
   - **Fix:** Ensure Docker is started (`sudo systemctl start docker` on Linux, or opening Docker Desktop on Mac). If deploying to Oracle, note that `03_clean_deploy.sh` runs on your Mac and drives the VM over ssh -- Docker must be running **locally** only for `publish.sh`.

2. **Stray Testcontainers (`test_pg`) Surviving Docker Prune:**
   - **Error:** Finding a `test_pg` or other random PostGIS container running even after executing `docker system prune -af`.
   - **Cause:** When Java integration tests run, Testcontainers may dynamically spin up a PostGIS container (e.g., `kartoza/postgis:16-3.4` mapped internally to `5432/tcp`). If a test run is aborted or fails abruptly, the container is left running. Because `docker system prune` only removes *stopped* containers, these actively running orphans survive teardowns and consume VM memory.
   - **Fix:** We added `docker rm -f test_pg 2>/dev/null || true` to our deployment scripts before they spin up infrastructure. However, you can also run `docker ps` to identify any rogue running containers, and stop/rm them manually before running a clean deploy.

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

6. **Hardcoded `FoodDelivery` vs `Food Delivery.nosync` directory on Remote VMs:**
   - **Error:** Scripts fail because they try to `cd FoodDelivery/Deployment`, or creating rogue folders named `FoodDelivery` that don't match the live deployment.
   - **Cause:** When working remotely, AI agents or developers might mistakenly hardcode `FoodDelivery` because it's easier to type than dealing with spaces in `Food Delivery.nosync`. The live deployment is exclusively housed in `Food Delivery.nosync`.
   - **Fix:** **Never** use or create a directory named `FoodDelivery` on the remote Oracle environment. Always explicitly reference `'Food Delivery.nosync'` in all deployment scripts (e.g. `COMPOSE_DIR="Food Delivery.nosync/Deployment"`).

6. **Database Migration Failures (e.g., Relation Does Not Exist):**
   - **Error:** When running manual SQL migration scripts (like data transfer), you get `relation "some_table" does not exist`.
   - **Cause:** Either the script is connecting to the wrong database (e.g., `\c wrong_db`), or the application (via Flyway) hasn't started and initialized the schema yet.
   - **Fix:** Make sure the services have fully started and Flyway migrations have completed. Double check that `docker compose logs {service-name}` shows `Successfully applied X migrations`. Check you are connecting to the correct DB name defined in `{service-name}.yml`.

7. **Application Fails to Start (UnsatisfiedDependencyException):**
   - **Error:** `Parameter 0 of constructor in ... required a bean of type ... that could not be found.`
   - **Cause:** Often caused when using shared components from a common library (`com.fooddelivery.common`) and your service's `@SpringBootApplication` doesn't scan that package.
   - **Fix:** Update your main application class to include: `@SpringBootApplication(scanBasePackages = {"com.fooddelivery.your_service", "com.fooddelivery.common"})`.

9. **Security Context or Web Security Failing to Load in New Service:**
   - **Error:** Security configurations are ignored or missing bean errors related to security filters.
   - **Cause:** Relying purely on `@SpringBootApplication(scanBasePackages = ...)` sometimes doesn't properly trigger the `@EnableWebSecurity` initialization from the common library due to bean load ordering.
   - **Fix:** Always create a `SecurityConfig.java` in your new microservice's config package that explicitly imports the common security configuration:
     ```java
     package com.fooddelivery.{service_name}.config;
     import com.fooddelivery.common.security.CommonSecurityConfig;
     import org.springframework.context.annotation.Configuration;
     import org.springframework.context.annotation.Import;
     
     @Configuration
     @Import(CommonSecurityConfig.class)
     public class SecurityConfig {
     }
     ```

10. **Ledger/Outbox Services Silently Failing or Missing Beans:**
    - **Error:** The application starts but outbox events are never processed, or it fails because it can't find beans related to `OutboxProcessor`.
    - **Cause:** If your microservice leverages the transactional outbox pattern from `CommonLibrary`, you must explicitly enable the background scheduled tasks and the outbox configuration.
    - **Fix:** Add `@EnableOutbox` and `@EnableScheduling` to your main `@SpringBootApplication` class:
      ```java
      @SpringBootApplication(scanBasePackages = {"com.fooddelivery.your_service", "com.fooddelivery.common"})
      @EnableOutbox
      @EnableScheduling
      public class YourServiceApplication { ... }
      ```

11. **Application Fails to Start (UnsatisfiedDependencyException for Common Beans due to Early Initialization):**
    - **Error:** `Parameter 0 of constructor in CommonSecurityConfig required a bean of type SecurityContextFilter that could not be found.` (even when both classes are in `CommonLibrary` and the package is scanned).
    - **Cause:** Some Spring features (like `@EnableOutbox` which sets up scheduled tasks) can trigger eager initialization of configuration classes. If `CommonSecurityConfig` is evaluated before the component scanner has discovered its dependencies (like `@Component` annotated filters), it will crash.
    - **Fix:** In your shared configuration classes (e.g., `CommonSecurityConfig`), do not rely purely on the consuming microservice's component scan to provide internal dependencies. Instead, use `@Import` explicitly for required beans. For example:
      ```java
      @Configuration
      @EnableWebSecurity
      @Import(SecurityContextFilter.class) // Explicitly load this bean instead of waiting for component scan
      public class CommonSecurityConfig {
          // constructor using SecurityContextFilter
      }
      ```

12. **Kafka Consumer Failing to Create Retry/DLQ Topics:**
    - **Error:** Spring Kafka application starts but silently fails to route errors to DLQ, or crashes when a message fails because the retry topics (`<topic>-retry-0`, `<topic>-dlt`) do not exist.
    - **Cause:** When using `@RetryableTopic` on a `@KafkaListener`, if `autoCreateTopics` is set to `"false"`, Spring will not automatically create the necessary DLQ and Retry topics. While the main topic might be auto-created by the Kafka broker itself, the broker's auto-creation doesn't understand Spring's complex retry topic naming conventions.
    - **Fix:** Ensure that `@RetryableTopic` either omits the `autoCreateTopics` flag (it defaults to `true`) or explicitly sets `autoCreateTopics = "true"` so that Spring Boot can properly configure and provision the retry topic topology on startup.

13. **Application Crashes due to Missing Properties for Common Beans (e.g. NullPointerException or BeanCreationException):**
    - **Error:** `java.lang.NullPointerException: The URI scheme of endpointOverride must not be null.` or exceptions related to missing properties when trying to instantiate beans from `com.fooddelivery.common.config` (like `CloudflareR2Config` or `AwsSesConfig`).
    - **Cause:** When you add `@SpringBootApplication(scanBasePackages = {"com.fooddelivery.your_service", "com.fooddelivery.common"})`, Spring Boot scans and eagerly initializes **all** `@Configuration` classes inside the common library. If your specific microservice doesn't configure the required properties for those global components in its `.yml` file (for instance, a microservice that doesn't need file uploads won't have `r2.endpoint`), the application crashes on boot.
    - **Fix (App Side):** If you only added `scanBasePackages = "com.fooddelivery.common"` to get access to JPA entities or repositories (like the outbox pattern), remove it! Instead, use precise scanning: `@EnableJpaRepositories(basePackages = {"com.fooddelivery.your_service", "com.fooddelivery.common"})` and `@EntityScan(basePackages = {"com.fooddelivery.your_service", "com.fooddelivery.common"})`.
    - **Fix (Common Library Side):** Ensure that configurations in the common library that depend on environment properties use conditionals. For example, add `@ConditionalOnExpression("!'${your.property:}'.isEmpty()")` on the `@Configuration` class so it only initializes when the consuming microservice actually provides the configuration.

16. **Transient Connection Errors on Fresh Start:**
    - **Error:** `java.net.ConnectException: Connection refused` or `SocketTimeoutException` in Eureka/Kafka during the first 30-60 seconds.
    - **Cause:** Microservices booting concurrently in Docker Compose. Eureka clients attempt to register before Eureka servers are fully initialized, and Kafka clients attempt to connect before Zookeeper/Kafka broker election completes.
    - **Fix:** This is completely normal behavior in distributed systems. The services will retry automatically and resolve themselves once the infrastructure is fully up (usually within a minute). If the logs eventually say `Healthy` and `Started`, no action is required.

19. **Complete Tear-down for Fresh Deployments:**
    - **Error:** Stale database data or old cached Docker layers interfere with a newly deployed service.
    - **Cause:** A normal deploy never removes named volumes, so the Postgres data volume survives. To start from an empty database use `03_clean_deploy.sh --wipe`, then recreate the data with `DummyData/reset_remote_db.sh` and `run_remote_dummy_data.sh`.
20. **Eureka Peer Node Socket Read Timeout (ARM / Low Resource VMs):**
    - **Error:** `It seems to be a socket read timeout exception... you should set property 'eureka.server.peer-node-read-timeout-ms' to a bigger value` in the Eureka Server logs.
    - **Cause:** When deploying on ARM architecture or lower-tier VMs, initial startup and peer replication between Eureka nodes takes longer than the default 200ms read timeout.
    - **Fix:** Increase the `peer-node-read-timeout-ms` in the Eureka Server's `application.yml` (e.g., to `8000`).

21. **Spring Milestone Dependencies Fails to Resolve (e.g. Spring AI):**
    - **Error:** `package org.springframework.ai.tool.annotation does not exist` or `cannot find symbol class Tool` during a remote build, despite compiling successfully locally.
    - **Cause:** Milestone dependencies (e.g., `1.0.0-M6`) require explicitly defining the Spring Milestones repository in `pom.xml`. Even if defined, sometimes transitive resolution (like `spring-ai-core`) can be skipped or mis-cached on a remote VM, especially if you deploy using custom scripts that inject dependencies without updating the lockfiles/caches.
    - **Fix:** Ensure `<repositories>` are explicitly defined in the `pom.xml` where the dependency is used. For extreme cases where the remote cache is broken, explicitly add the missing transitive dependency (e.g. `spring-ai-core`), or manually sync your local `~/.m2/repository` for that specific package (e.g., `rsync -avz ~/.m2/repository/org/springframework/ai ubuntu@host:/home/ubuntu/.m2/repository/org/springframework/ai`) to forcefully mirror the functional local cache.

22. **Flyway Migration Failure due to Oracle-Specific Syntax in PostgreSQL Database:**
    - **Error:** `org.postgresql.util.PSQLException: ERROR: type "raw" does not exist` or `type "varchar2" does not exist` during application startup when Flyway attempts migration.
    - **Cause:** The migration SQL file `V1__init_*.sql` was written using Oracle-specific datatypes (`RAW`, `VARCHAR2`, `NUMBER`) instead of PostgreSQL-compatible datatypes. Since the infrastructure uses PostgreSQL, Flyway fails to execute the migration.
    - **Fix:** Rewrite the SQL migration script to use PostgreSQL standard types: replace `RAW(16)` with `UUID`, `VARCHAR2` with `VARCHAR`, and `NUMBER` with `INTEGER`/`NUMERIC`. Because Flyway records failed migrations, you must also SSH into the deployment, connect to PostgreSQL (`docker exec -i shared_postgres psql -U postgres -d <db_name>`), and run `DROP TABLE IF EXISTS flyway_schema_history;` before rebuilding and restarting the container.

23. **Database Connection Limit Reached (too many clients already):**
    - **Error:** Services fail to start or connect to the database with `FATAL: sorry, too many clients already`.
    - **Cause:** When you have many microservices (e.g. 15+) connecting to a single Postgres instance, each service's Hikari connection pool opens multiple connections (default 10-30), quickly exhausting the Postgres default `max_connections` limit (100).
    - **Fix:** Update `docker-compose.yml` to increase the Postgres connection limit:
      ```yaml
      postgres:
        environment:
        - EXTRA_CONF=max_connections=500
      ```

24. **Services Not Appearing in Eureka Dashboard:**
    - **Error:** The service starts correctly locally or in Docker, but it doesn't appear in the Eureka UI at `http://<ip>:8761`.
    - **Cause:** Several possible issues:
      - Incorrect Eureka URL in the `deployment/{service-name}.yml`.
      - Missing or incorrect basic auth credentials (`EUREKA_USER`, `EUREKA_PASSWORD`).
      - Service crashed shortly after startup.
    - **Fix:** Verify `eureka.client.serviceUrl.defaultZone` matches the exact URL (including basic auth if used) of the Eureka server. Check the container logs `docker compose logs -f <service-name>` for any startup crashes or connection refused errors to Eureka.

25. **Application Fails to Start (Missing DataSource for Non-Database Services):**
    - **Error:** `Failed to configure a DataSource: 'url' attribute is not specified and no embedded datasource could be configured.`
    - **Cause:** Excluding `DataSourceAutoConfiguration` and `HibernateJpaAutoConfiguration` is not enough. Spring Boot will still try to configure JPA repositories and demand an `entityManagerFactory`.
    - **Fix:** Add `org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration` to your `SPRING_AUTOCONFIGURE_EXCLUDE` environment variable in `docker-compose.yml`.

26. **Docker Compose YAML Syntax Errors for depends_on:**
    - **Error:** `yaml: line XX: did not find expected key` or similar YAML parsing errors when using `docker compose`.
    - **Cause:** Incorrect indentation of the `condition: service_healthy` key under the service name in the `depends_on` block.
    - **Fix:** Ensure the dictionary is properly indented. E.g.:
      ```yaml
      depends_on:
        config-service:
          condition: service_healthy
      ```

27. **Schema and Entity Field Synchronization Failures:**
    - **Error:** Hibernate schema validation fails at boot time with `wrong column type encountered` or `missing column` in `outbox_events` (or similar shared tables).
    - **Cause:** When creating a Flyway migration (`V1__init_schema.sql`), column names or types slightly differ from the JPA Entity definitions. For example, naming the column `event_type` when the entity has `@Column(name = "type")`, or using `TEXT` when the entity expects `JSONB` via `@JdbcTypeCode(SqlTypes.JSON)`.
    - **Fix:** Always strictly verify that the SQL table definitions exactly match the `@Column` names and types in the JPA entity classes, especially when copying schemas from other services or manually creating outbox tables.

28. **KafkaHeader Compilation Errors (RECEIVED_PARTITION_ID):**
    - **Error:** `cannot find symbol ... KafkaHeaders.RECEIVED_PARTITION_ID`
    - **Cause:** In newer versions of Spring Kafka (3.x+), `RECEIVED_PARTITION_ID` is deprecated and removed.
    - **Fix:** Use `KafkaHeaders.RECEIVED_PARTITION` instead.

29. **Application Crash Due to Missing `idempotency_keys` Table:**
    - **Error:** Application crashes on startup with `SchemaManagementException: Schema-validation: missing table [idempotency_keys]`.
    - **Cause:** If your microservice uses `CommonLibrary` entities, it will automatically scan and try to manage the `IdempotencyKey` entity. If your service doesn't have a Flyway migration script to create this table, Hibernate's schema validation (`validate`) will fail.
    - **Fix:** Ensure that every microservice depending on `CommonLibrary` and using JPA includes a Flyway migration (e.g. `V4__create_idempotency_keys.sql`) with `CREATE TABLE IF NOT EXISTS idempotency_keys ( key VARCHAR(255) PRIMARY KEY, created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP );`.

30. **HikariCP "Apparent connection leak detected" During Boot:**
    - **Error:** `java.lang.Exception: Apparent connection leak detected` in service logs during startup.
    - **Cause:** This is often a **false positive** warning during initial boot. If Flyway migrations or large JPA context initializations take longer than Hikari's `leakDetectionThreshold`, Hikari assumes the connection is leaked.
    - **Fix:** As long as the service proceeds to print `Started <ApplicationName>` directly afterward, this can be safely ignored. The connection is returned to the pool once the long-running startup task completes.

31. **Kafka Timeout Exception (Timed out waiting for a node assignment):**
    - **Error:** `org.apache.kafka.common.errors.TimeoutException: Timed out waiting for a node assignment` or `NetworkClient: Connection to node -1 (localhost/127.0.0.1:9092) could not be established.`
    - **Cause:** The microservice is trying to connect to a default `localhost:9092` broker instead of the internal Docker Kafka broker. This happens if `spring.kafka.bootstrap-servers` is missing from the `{service-name}.yml`.
    - **Fix:** Ensure your service's YAML in `Deployment/` has `spring.kafka.bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS:kafka:29092}` configured under `spring:`.

32. **OpenTelemetry Connection Refused (api-gateway connecting to localhost:4318):**
    - **Error:** `Failed to connect to localhost/[0:0:0:0:0:0:0:1]:4318`
    - **Cause:** Micrometer tracing or OpenTelemetry agents are enabled by default in the microservice, but the `MANAGEMENT_OTLP_TRACING_ENDPOINT` defaults to `localhost`.
    - **Fix:** If no Otel collector is deployed in `docker-compose.yml`, this is benign, but to disable the warning, explicitly configure or disable tracing endpoints.

33. **GCP Default Credentials Not Found:**
    - **Error:** `Your default credentials were not found. To set up Application Default Credentials for your environment, see...`
    - **Cause:** A microservice (e.g., `communication-integration`) initializing Google Cloud SDKs inside a Docker container doesn't have access to your local machine's `gcloud` credentials.
    - **Fix:** Either mock the beans using a `@Profile("dev")` configuration, or inject a service account key into the container via volume mounts and `GOOGLE_APPLICATION_CREDENTIALS`.

34. **Maven Build Node/NPM Version Mismatch Warnings (EBADENGINE):**
    - **Error:** `EBADENGINE Unsupported engine` warnings during the `food-delivery-app-ui` build using `frontend-maven-plugin`.
    - **Cause:** The Node.js version installed by the plugin doesn't perfectly match the version engines declared in some dependencies.
    - **Fix:** This is a benign warning and does not prevent the UI from building successfully (`BUILD SUCCESS`). No action is required.

35. **Docker Compose "version is obsolete" Warning:**
    - **Error:** `WARN[0000] /home/ubuntu/.../docker-compose.yml: the attribute version is obsolete, it will be ignored`
    - **Cause:** Newer versions of Docker Compose ignore the top-level `version:` field in `docker-compose.yml`.
    - **Fix:** This is a benign warning. You can safely ignore it or remove the `version: '3.8'` (or similar) line from the `docker-compose.yml` files.

36. **API Gateway HTTP 503 Service Unavailable During Initial Boot:**
    - **Error:** `HTTP 5xx Server Error via Zodios` with `status=503` in the API Gateway or UI logs.
    - **Cause:** Immediately after a clean deployment, the UI might make requests before backend services have fully registered with the Eureka server and routes are propagated to the API Gateway.
    - **Fix:** This is a transient error expected during cold starts. Simply wait 1-2 minutes for Eureka discovery to synchronize and refresh the UI.

37. **Dummy Data Insertion Fails with 'relation does not exist':**
    - **Error:** `ERROR: relation "users" does not exist` when running `run_remote_dummy_data.sh`.
    - **Cause:** After a completely clean deployment, microservices take a few minutes to boot and generate their schemas via Flyway or Hibernate. If the dummy data script is executed before the tables are created, it aborts the transactions.
    - **Fix:** You must wait for the schemas to be fully generated. Use a script that polls the `information_schema.tables` to confirm tables like `identity_db.users` exist before inserting data.

38. **Compilation Failure due to Missing Methods on DTO Builders (OpenAPI Compatibility):**
    - **Error:** `cannot find symbol: method ...` (e.g. `isDeliverable(boolean)`) on a DTO builder during the Maven package phase.
    - **Cause:** When working with DTOs, developers or AI agents might hallucinate fields or methods that look correct but don't exist. If the DTO is auto-generated by OpenAPI or lacks those fields, the local IDE might sometimes not catch it immediately, but the Maven build will fail.
    - **Fix:** Always verify the actual fields in the DTO class before using its builder. If it is an OpenAPI-generated model, you must update the OpenAPI spec (`openapi.yaml`) and regenerate it, or refrain from using non-existent fields and handle the logic elsewhere (e.g., throwing an `IllegalArgumentException` in the service layer).

40. **JPA Repositories / Entities Not Found in Local Microservice Package:**
    - **Error:** When using `@EnableJpaRepositories` or `@EntityScan` to include the `common` library, the microservice's *own* repositories or entities stop working.
    - **Cause:** Once you explicitly use `@EnableJpaRepositories` or `@EntityScan`, Spring Boot completely turns off its default behavior of scanning the current package. It will *only* scan what you explicitly specify.
    - **Fix:** Always include your microservice's base package alongside the common package. For example: `@EntityScan(basePackages = {"com.fooddelivery", "com.fooddelivery.common.entity"})` and `@EnableJpaRepositories(basePackages = {"com.fooddelivery", "com.fooddelivery.common.repository"})`.

41. **Service Crashes with 'Connection Refused' to 'localhost:5432' Despite DB_URL in docker-compose.yml:**
    - **Error:** `Unable to obtain connection from database: Connection to localhost:5432 refused` during startup, typically from Flyway or HikariCP.
    - **Cause:** The service's local `application.yml` is hardcoded to fallback to `localhost:5432` using a specific variable name like `SPRING_DATASOURCE_URL` instead of a generic `DB_URL`. If you only set `DB_URL` in `docker-compose.yml`, it has no effect on this specific service, causing it to fall back to `localhost`.
    - **Fix:** Check the service's `application.yml` or config server file to see exactly which variable it expects (e.g. `SPRING_DATASOURCE_URL`). Add that exact environment variable to `docker-compose.yml` (e.g., `SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/db_name`) to correctly override the localhost fallback.

### Expected Warnings on OCI Free Tier (Ampere A1)
During boot, you may see the following warnings in the logs of microservices (like `customer-service`):
```text
java.lang.Exception: Apparent connection leak detected
```
**Resolution**: This is a non-fatal warning generated by `HikariPool-1 housekeeper`. Because the OCI Ampere instances are heavily CPU-constrained during the simultaneous boot-up of 15+ Spring Boot containers, the connection acquisition latency spikes, triggering this false positive. It is safe to ignore as long as the container eventually reaches `Started` state and does not crash.

### Disk Space Exhaustion on OCI Free Tier (Ampere A1)
Nothing is built on the VM any more, so the build-time exhaustion is gone. What still fills the disk is **accumulated pulled images**: every deploy pulls a new git-sha tag and the previous one stays. 
**Error**: `no space left on device`, or a pull that fails partway.

**Fix**: prune old images on the VM — `docker image prune -a -f` removes everything not used by a
running container, which is safe because any tag can be pulled again from OCIR. `publish.sh`
already prunes each image locally after pushing it.
**Resolution**: Always build microservices sequentially rather than in parallel to keep peak memory and disk usage low. Use `docker system prune -a --volumes -f` before fresh deployments to clear old image layers, stopped containers, and anonymous volumes that accumulate from previous builds.

42. **Local Changes Not Reflecting in Remote Deployment (Stale Code):**
    - **Error:** You make a bug fix locally, deploy, and the container still crashes with the exact same error.
    - **Cause:** The VM runs whatever image tag it was told to run. Publishing without rebuilding,
      or deploying a tag older than your fix, both look like a successful deploy. `publish.sh`
      rejects a jar older than its sources, and `deploy.sh` verifies the container ended up on the
      intended image -- check its output rather than assuming.
    - **Fix:** Only `Deployment/` is ever synced now, and only for config changes -- code reaches
      the VM as a published image. Quote the destination so the space survives:
      `ubuntu@HOST:"/home/ubuntu/Food Delivery.nosync/Deployment/"`. Check the exit code; a
      mis-quoted path writes to `/home/ubuntu/Food` and reports success.

43. **Rsync Dropping Connection or Stalling on Large Transfers:**
    - **Error:** `client_loop: send disconnect: Broken pipe` or `Connection reset by peer` or rsync just hangs during transfer.
    - **Cause:** SSH connections can time out or be dropped by the network/firewall if there is no activity on the control channel, especially on slow network connections or when transferring large codebases.
    - **Fix:** Pass SSH keep-alive options to rsync using the `-e` flag. For example: `rsync -avz -e "ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3" ...`.

45. **Fixing Schema Validation Errors on Live DB (Flyway Checksum Mismatch):**
    - **Error:** \`FlywayException: Validate failed: Migration checksum mismatch for migration version 1\` after trying to fix a missing column in \`V1__init_schema.sql\`.
    - **Cause:** PostgreSQL DDL (schema creation) in Flyway is transactional. If \`V1__init_schema.sql\` executes successfully, Flyway marks it as SUCCESS in \`flyway_schema_history\`. If the application subsequently crashes during Hibernate schema validation (e.g. \`missing column [food_cost]\`), modifying the already-applied \`V1\` file locally and re-deploying will cause a checksum mismatch error because the DB remembers the old file's hash.
    - **Fix:** **Never** modify an already applied Flyway migration script. Always create a new migration (e.g., \`V2__add_food_cost.sql\`) containing the \`ALTER TABLE ... ADD COLUMN ...\` statement. This allows Flyway to safely apply the fix on top of the existing schema without checksum errors.

46. **Schema Validation Missing Columns Loop:**
    - **Error:** Spring Boot container crashes repeatedly with \`SchemaManagementException: Schema-validation: missing column [...]\`.
    - **Cause:** When you set \`spring.jpa.hibernate.ddl-auto=validate\`, Hibernate strictly verifies that the DB schema matches the entity definitions. If multiple columns are missing, it throws an exception on the *first* missing column it detects, and aborts. Once you fix that one and restart, it will crash again on a *second* missing column, resulting in a frustrating loop of single-column fixes.
    - **Fix:** Do not just fix the one column mentioned in the error! Instead, immediately inspect your \`Entity.java\` against your \`V1__init_schema.sql\` (and subsequent migrations) to identify *all* missing columns. Bundle all missing columns into a single new migration file (e.g. \`V3__add_missing_columns.sql\`) rather than fixing them one by one.

47. **Multi-Module Project Parent POM Not Resolving Remotely:**
    - **Error:** Remote deployment fails during Maven build with missing artifact errors for internal dependencies (e.g., `identity-signing:jar is missing` or `dependencies.dependency.version is missing`).
    - **Cause:** `FoodDeliveryParent` carries dependency management for the whole architecture but
      is not part of the root aggregator POM, so building the aggregator never installs it and
      downstream modules cannot resolve managed versions.
    - **Fix:** Run `mvn -N install -f FoodDeliveryParent/pom.xml` before building the workspace.
      This still applies on a Mac and in CI -- it is the reason a clean checkout fails where a
      warm `~/.m2` succeeds. It no longer has anything to do with the VM.

### Spring Boot `jarmode=tools` extraction fails

- **Error:** `Unsupported jarmode 'tools'` while building the image.
- **Cause:** `-Djarmode=tools ... extract` exists from Spring Boot 3.3.x. On 3.1.x and earlier the
  capability is not there in the same form.
- **Fix:** Move `spring-boot-starter-parent` to 3.3.0+ with a matching `spring-cloud-dependencies`
  (2023.0.2+). Every Dockerfile in this repo uses the layered extract, so a module left behind on an
  older parent fails only at image build time, long after its jar built cleanly.

### Why Java services build with the workspace root as context

A service that depends on `CommonLibrary` cannot be built from its own directory — the Docker build
would not find the sibling module's jar.

1. `mvn package` first, so every module has its jar in `target/`.
2. `docker-compose.yml` sets `context: ../` with `dockerfile: <Module>/Dockerfile`, and the
   Dockerfile copies the pre-built `<Module>/target/*.jar` from that context. Nothing runs Maven
   inside the image build.
3. `food-delivery-app-ui` is the exception: its context is its own directory because its Dockerfile
   does `COPY nginx.conf`. This is recorded per-service in `Deployment/service-map.tsv`.

### Tracing Configuration Checklist
- Ensure a Jaeger (or OpenTelemetry Collector) container is running and exposed in `docker-compose.yml`.
- Ensure all microservices have `OTLP_ENDPOINT=http://jaeger:4318/v1/traces` correctly injected in their `environment:` block so they don't spam errors trying to connect to their own internal `localhost:4318`.
- Failure to do this will result in `java.net.ConnectException` logs filling up memory and causing health check timeouts.
