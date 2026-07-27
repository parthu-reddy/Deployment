# Standardized Database Initialization Approach for Microservices

This document defines the **Mandatory Standard** for database schema creation, evolution, and JPA configuration across all microservices in the Food Delivery Platform (e.g., `CustomerApplication`, `RestaurantApplication`, `DeliveryExecutiveApplication`, `IdentityService`, `PaymentGatewayIntegration`, `CommunicationIntegration`, `GovernmentIDValidationService`).

Whenever an AI agent or developer creates a new microservice or modifies an existing service's database schema, **YOU MUST FOLLOW THIS EXACT APPROACH WITHOUT EXCEPTION**.

---

## 1. Core Architectural Principles

1. **Pure Flyway-Driven DDL**: All database objects (schemas, tables, columns, constraints, foreign keys, indexes, extensions, and custom PostgreSQL `ENUM` types) **MUST** be explicitly and authoritatively defined in Flyway SQL migration scripts located in `src/main/resources/db/migration/`.
2. **Read-Only Hibernate Validation**: Hibernate / Spring Data JPA is strictly prohibited from generating or modifying database schemas at runtime. In all deployment configuration files (`Deployment/<service-name>.yml`), `spring.jpa.hibernate.ddl-auto` **MUST** be set to `validate` (never `update`, `create`, or `create-drop` in dev or production profiles).
3. **Deterministic Startups & Fail-Fast Protection**: By enforcing `ddl-auto: validate`, the Spring Boot application will immediately fail to boot if the Java `@Entity` mappings diverge from the Flyway-generated database schema. This eliminates silent runtime corruption and schema drift across environments.

---

## 2. Step-by-Step Implementation Guide for Services

### Step 1: Include Flyway & PostgreSQL Dependencies (`pom.xml`)
Every database-backed microservice must include the PostgreSQL driver and Flyway migration engine in its `pom.xml`:

```xml
<!-- PostgreSQL JDBC Driver -->
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
</dependency>

<!-- Flyway Migration Engine -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-database-postgresql</artifactId>
</dependency>
```

---

### Step 2: Write Authoritative Flyway Migration Scripts
Place all SQL migration scripts in `src/main/resources/db/migration/` following the strict naming convention: `V<VERSION>__<Description>.sql` (e.g., `V1__init_schema.sql`, `V2__add_status_column.sql`). 
*Note the **double underscore (`__`)** separating the version number from the description.*

#### Critical Rules for SQL Migration Scripts:
1. **Idempotency & Safety**: Always use defensive SQL constructions where applicable:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   CREATE TABLE IF NOT EXISTS customers (...);
   CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone_number);
   ```
2. **Custom PostgreSQL ENUM Types**: Define native enum types explicitly before referencing them in table columns:
   ```sql
   CREATE TYPE verification_status AS ENUM ('PENDING', 'VERIFIED', 'REJECTED', 'APPROVED');
   
   CREATE TABLE IF NOT EXISTS executive_documents (
       document_id UUID PRIMARY KEY,
       executive_id UUID NOT NULL,
       api_verification_status verification_status DEFAULT 'PENDING',
       created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );
   ```
3. **Altering Existing Enums / Tables in Later Migrations**: Never modify older `V*` migration files once committed. Create a new numbered migration script:
   ```sql
   -- V2__add_new_status.sql
   ALTER TYPE verification_status ADD VALUE IF NOT EXISTS 'MANUAL_REVIEW';
   ALTER TABLE executive_documents ADD COLUMN expiry_date DATE;
   ```

---

### Step 3: Configure Spring Cloud Deployment YAML (`Deployment/<service-name>.yml`)
In the central Spring Cloud Config repository (stored in the root `Deployment/` directory), configure the datasource, JPA validation mode, and Flyway migration settings:

```yaml
spring:
  datasource:
    url: ${DB_URL:jdbc:postgresql://postgres:5432/<db_name>}
    username: ${DB_USERNAME:postgres}
    password: ${DB_PASSWORD:password}
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 30
      minimum-idle: 10
      connection-timeout: 30000
      idle-timeout: 300000
      max-lifetime: 1200000
  jpa:
    hibernate:
      # CRITICAL: Must ALWAYS be validate. Never use update or create!
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
  flyway:
    enabled: true
    baseline-on-migrate: true
    baseline-version: "0"
```

---

### Step 4: Map Java `@Entity` Classes Correctly
Ensure your JPA `@Entity` classes match the Flyway database schema exactly to pass Hibernate startup validation:

1. **Table & Column Naming**: Explicitly specify names using `@Table(name = "exact_table_name")` and `@Column(name = "exact_column_name")` (in snake_case).
2. **PostgreSQL Custom Enum Mapping**: To map Java enums to PostgreSQL custom `ENUM` columns without Hibernate throwing validation exceptions, combine `@Enumerated(EnumType.STRING)` with `@JdbcType(PostgreSQLEnumJdbcType.class)` and explicitly declare the `columnDefinition`:
   ```java
   import org.hibernate.annotations.JdbcType;
   import org.hibernate.dialect.PostgreSQLEnumJdbcType;
   
   @Enumerated(EnumType.STRING)
   @JdbcType(PostgreSQLEnumJdbcType.class)
   @Column(name = "api_verification_status", columnDefinition = "verification_status", nullable = false)
   private VerificationStatus apiVerificationStatus;
   ```
3. **PostgreSQL JSONB Mapping**: Map `JSONB` columns using `@JdbcTypeCode(SqlTypes.JSON)`:
   ```java
   import org.hibernate.annotations.JdbcTypeCode;
   import org.hibernate.type.SqlTypes;
   
   @JdbcTypeCode(SqlTypes.JSON)
   @Column(name = "api_raw_response", columnDefinition = "jsonb")
   private String apiRawResponse;
   ```
4. **UUID Primary Keys**: Use `UUID` types with generation strategies:
   ```java
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID documentId;
    ```
5. **CommonLibrary & OutboxEventEntity Requirement**: Because `CommonLibrary` includes `OutboxEventEntity` mapped to `@Table(name = "outbox_events")`, any microservice importing `CommonLibrary` and scanning for entities in `com.fooddelivery` will expect the `outbox_events` table to exist in its database when `ddl-auto: validate` runs. Therefore, **every microservice using CommonLibrary MUST include the `outbox_events` table and index creation in its Flyway schema migrations**:
   ```sql
   CREATE TABLE IF NOT EXISTS outbox_events (
       id UUID PRIMARY KEY,
       aggregate_type VARCHAR(100) NOT NULL,
       aggregate_id VARCHAR(100) NOT NULL,
       type VARCHAR(100) NOT NULL,
       payload JSONB NOT NULL,
       status VARCHAR(20) DEFAULT 'UNPROCESSED',
       processed_at TIMESTAMP,
       error_message TEXT,
       retry_count INT DEFAULT 0,
       created_at TIMESTAMP NOT NULL DEFAULT NOW()
   );

   CREATE INDEX IF NOT EXISTS idx_outbox_status_polling ON outbox_events(status, created_at) WHERE status IN ('UNPROCESSED', 'FAILED');
   ```

---

## 4. Mandatory Checklist for AI Agents & Code Reviews
Before finishing any task involving database schema creation or service onboarding, check off this mandatory checklist:
- [ ] `flyway-core` and `flyway-database-postgresql` dependencies are present in `pom.xml`.
- [ ] Migration scripts are placed in `src/main/resources/db/migration/` with valid `V<VERSION>__<Description>.sql` naming.
- [ ] All table definitions, foreign keys, indexes, and custom enums are created via Flyway DDL (no table reliance on JPA auto-generation).
- [ ] The mandatory `outbox_events` table is included in the Flyway migration scripts if importing `CommonLibrary`.
- [ ] `spring.jpa.hibernate.ddl-auto: validate` is set in `Deployment/<service-name>.yml`.
- [ ] `spring.flyway.enabled: true` and `baseline-on-migrate: true` are configured in `Deployment/<service-name>.yml`.
- [ ] The service compiles and starts cleanly without any Hibernate schema validation errors.
