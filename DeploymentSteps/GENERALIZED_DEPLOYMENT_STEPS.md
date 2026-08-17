# Generalized Microservice Deployment Instructions

This guide provides a comprehensive checklist and instructions for taking a newly created microservice and deploying it in the existing Food Delivery architecture on the Oracle environment using Docker Compose and Eureka.

## Prerequisites
- Your service should be built on Spring Boot.
- The service must include the `spring-cloud-starter-netflix-eureka-client` dependency in its `pom.xml`.
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

> [!WARNING]
> Remember that the `Deployment/` folder maps directly into the ConfigService. If you add or modify `{service-name}.yml` or `api-gateway.yml`, you **must** sync the `Deployment` folder to the remote Oracle server (e.g., using `rsync` in `deploy_recent_changes.sh`), and you must restart the affected services for the changes to take effect.

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
If you are deploying this for the very first time on a fresh VM, you can run the master script `Deployment/OracleDeployment/03_deploy_dev.sh` which tears down and reconstructs everything. 
*(Note: You must run this script from the root of the repository, not from inside the `Deployment` folder, because it relies on relative paths like `cd ..`)*

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

8. **Application Fails to Start (Missing Bean from CommonLibrary on Remote VM):**
   - **Error:** `Parameter 0 of constructor in ... required a bean of type ... that could not be found.` (even when you verify the bean exists locally and your `@SpringBootApplication` has `scanBasePackages` set correctly).
   - **Cause:** If you modified `CommonLibrary` locally to add the missing bean, but only `rsync`ed your new microservice folder to the remote VM, building the microservice on the VM will pull the *stale, cached* version of `CommonLibrary` from the VM's local `~/.m2` repository.
   - **Fix:** Always sync the entire workspace (including `CommonLibrary`) to the remote VM. Then, SSH into the VM, navigate to `CommonLibrary`, and run `mvn clean install -DskipTests` to update the VM's local Maven cache *before* rebuilding your microservice container.

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

14. **Compilation Failure in Unrelated Shared Module (e.g. CommonLibrary) During Deployment:**
    - **Error:** When running `mvn clean package -pl {ServiceName} -am -DskipTests`, the build fails in `CommonLibrary` because `testCompile` encounters missing symbols or deprecated warnings.
    - **Cause:** Maven's `-DskipTests` only skips *executing* the tests, but it still compiles them (meaning the `testCompile` phase runs). If a shared library like `CommonLibrary` has broken tests, it will halt the build of your microservice.
    - **Fix:** Update your deployment scripts to use `-Dmaven.test.skip=true` instead of `-DskipTests`. This instructs Maven to skip both the compilation and execution of tests, speeding up deployment and avoiding issues caused by broken tests in dependencies.

15. **Permission Denied When Executing Remote Deployment Scripts:**
    - **Error:** `bash: line 1: ./Deployment/OracleDeployment/03_deploy_dev.sh: Permission denied`
    - **Cause:** When syncing deployment scripts (e.g. via `rsync`) from a local machine to a remote server like Oracle Cloud, the shell scripts may lose or not have the proper executable (`+x`) permissions on the remote filesystem.
    - **Fix:** Before executing the deployment script on the remote server, ensure you add execute permissions. For example, run `chmod +x Deployment/OracleDeployment/*.sh` over SSH before invoking the script.

16. **Transient Connection Errors on Fresh Start:**
    - **Error:** `java.net.ConnectException: Connection refused` or `SocketTimeoutException` in Eureka/Kafka during the first 30-60 seconds.
    - **Cause:** Microservices booting concurrently in Docker Compose. Eureka clients attempt to register before Eureka servers are fully initialized, and Kafka clients attempt to connect before Zookeeper/Kafka broker election completes.
    - **Fix:** This is completely normal behavior in distributed systems. The services will retry automatically and resolve themselves once the infrastructure is fully up (usually within a minute). If the logs eventually say `Healthy` and `Started`, no action is required.

17. **Sed Command Fails with "No such file or directory" during deployment on OCI:**
    - **Error:** `sed: can't read s/...: No such file or directory` when running deployment shell scripts on the Oracle Linux/Ubuntu VM.
    - **Cause:** macOS uses BSD `sed` while Ubuntu/OCI uses GNU `sed`. On macOS, `sed -i '' "s/...` is required for inline replacement without creating a backup file, but on GNU Linux, `sed -i "s/...` must be used. Using `sed -i ''` on Linux makes it interpret `''` as the file name, which causes it to fail.
    - **Fix:** Ensure all shell scripts running on the remote Oracle VM use GNU `sed` syntax (`sed -i`). If you edited the deployment script locally on a Mac and tested it, remember to revert it to the Linux syntax before syncing it to OCI.

18. **Deployment Directory Not Found Error:**
    - **Error:** `Error: 'Deployment' directory not found. Make sure you run this script from the root of the cloned repository.`
    - **Cause:** You ran the `03_deploy_dev.sh` script while currently inside the `Deployment/OracleDeployment/` directory. The script expects to be executed from the root of the repository (`Food Delivery.nosync/`).
    - **Fix:** Ensure that the shell command running the script uses the correct relative path from the root. For example: `cd 'Food Delivery.nosync' && bash Deployment/OracleDeployment/03_deploy_dev.sh` instead of `cd 'Food Delivery.nosync/Deployment/OracleDeployment' && bash 03_deploy_dev.sh`.

19. **Complete Tear-down for Fresh Deployments:**
    - **Error:** Stale database data or old cached Docker layers interfere with a newly deployed service.
    - **Cause:** `docker compose up --build` does not remove existing named volumes (like the Postgres data volume). If you change schema or need dummy data re-inserted, the old volume will persist.
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

39. **Intermittent "Package Does Not Exist" Errors for Internal Libraries During Full Deployment**:
    - **Error:** When running a full deployment script (e.g., `03_deploy_dev.sh`), a downstream service fails to compile with `package com.fooddelivery.common... does not exist`, despite `CommonLibrary` successfully building locally and syncing properly.
    - **Cause:** Occasionally, running the Maven aggregator build within a complex shell script on resource-constrained VMs can cause transient reactor resolution failures. Maven fails to map the newly compiled library to the downstream service's classpath.
    - **Fix:** Run the Maven build command manually outside of the script first. From the root of the project: `mvn clean package -Pdev -Dmaven.test.skip=true`. If the problem persists for a specific module, rebuild it with its dependencies explicitly using `mvn clean package -pl :<failed-service-name> -am -Dmaven.test.skip=true`.

### Expected Warnings on OCI Free Tier (Ampere A1)
During boot, you may see the following warnings in the logs of microservices (like `customer-service`):
```text
java.lang.Exception: Apparent connection leak detected
```
**Resolution**: This is a non-fatal warning generated by `HikariPool-1 housekeeper`. Because the OCI Ampere instances are heavily CPU-constrained during the simultaneous boot-up of 15+ Spring Boot containers, the connection acquisition latency spikes, triggering this false positive. It is safe to ignore as long as the container eventually reaches `Started` state and does not crash.
