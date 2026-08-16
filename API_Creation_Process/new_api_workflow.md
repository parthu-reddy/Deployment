# New API Creation Standard Operating Procedure (SOP)

This document provides a highly detailed, step-by-step workflow for creating a new API in the Food Delivery Platform. This process ensures tight alignment between backend implementations, OpenAPI specifications, and frontend Zodios runtime validations, preventing regression bugs and TypeScript compiler errors across the stack.

---

## 1. Backend Implementation & DTO Design (Spring Boot)

*   **Create the Endpoint:** Implement the new Spring Boot `@RestController` endpoint in the appropriate microservice. Map it explicitly using `@GetMapping`, `@PostMapping`, `@PutMapping`, or `@DeleteMapping`.
*   **Security Whitelisting & Context:** 
    *   **New Services:** If you are creating a brand new microservice, its main `@SpringBootApplication` class **must** include `@ComponentScan("com.fooddelivery")`. This ensures it inherits the `CommonSecurityConfig` from the `CommonLibrary`. Without this, Spring Boot defaults to locking down all endpoints (including the OpenAPI docs generator) with HTTP Basic Authentication, resulting in `0 byte` spec files and `401 Unauthorized` errors.
    *   **Public APIs:** If the new API is public (e.g., login, webhook, public callbacks) and does not require a JWT token, explicitly whitelist the route in the microservice's `SecurityConfiguration.java` using `requestMatchers("...").permitAll()`.
*   **Strong Typing:** Strictly type all `@RequestBody`, `@RequestParam`, `@PathVariable`, and `@RequestHeader` parameters using specific Data Transfer Objects (DTOs). You must avoid using generic `Map<String, Object>` or `JsonNode` for request/response payloads, as these generate useless generic OpenAPI schemas that the frontend cannot enforce.
*   **Validation:** Apply explicit `jakarta.validation` annotations to DTO fields (e.g., `@NotNull`, `@NotBlank`, `@Size(min = 1, max = 100)`, `@Min(0)`). Ensure that the `@RequestBody` parameter in the controller has the `@Valid` annotation to trigger the validation.

## 2. Swagger/Springdoc Annotations

*   **Explicit Definitions:** Do not rely solely on implicit Spring Boot generation. Use `@Operation(summary = "...", description = "...")` to describe the endpoint. Use `@ApiResponses` to explicitly define edge-case response codes (e.g., 400 Bad Request, 404 Not Found, 500 Internal Server Error) and their corresponding error DTOs.
*   **Implicit Parameters:** If your API requires a specific header (e.g., `X-Calling-Service`) that isn't bound to a method parameter, define it explicitly using the `@Parameter(in = ParameterIn.HEADER)` annotation so the frontend knows it's required.
*   **Path Variable Alignment:** Ensure path variables exactly match their intended frontend usage. If the frontend expects `/users/:userId`, the backend path must be mapped as `/users/{userId}`, not `/users/{id}`. This prevents Zodios strict-mode Category 3/5 errors where dynamic path segments fail to map correctly at compile time.

## 3. Remote OpenAPI Spec Generation

*   **Sync to Oracle VM:** Use the provided deployment scripts (e.g., `Deployment/DeploymentSteps/CustomerApplication/deploy_customer-service.sh`) to sync the microservice's code and `CommonLibrary` to the Oracle Dev VM.
*   **Build and Start:** The deployment script will execute `mvn clean package` remotely, build the Docker container, and start it via `docker compose up -d`.
*   **Extract Spec:** Once the container is healthy on the Oracle VM, the `springdoc-openapi` module will serve the spec at the container's Swagger endpoint. SSH into the VM (or use `fetch_openapi_remote.sh`) to `curl` the endpoint (e.g., `http://localhost:8092/v3/api-docs`) and save it to the remote `openapi.json` file.
*   **Sync to Local:** Using `rsync`, pull the generated `openapi.json` file from the Oracle server back to your local microservice directory (e.g., `CustomerApplication/openapi.json`).

## 4. Spec Synchronization (Source of Truth)

*   **Copy Spec:** Manually copy the generated `target/openapi.json` to the root of the microservice directory (e.g., `CustomerApplication/openapi.json`).
*   **Commit to VCS:** Commit this `openapi.json` file to version control. **This file acts as the absolute source of truth for the entire ecosystem.** Any drift between this file, the Java code, and the frontend TypeScript is considered a build failure.

## 5. Feign Client Generation (Inter-Service Communication)

*   *Skip this step if no other backend service needs to consume this new API.*
*   **Update CommonLibrary Specs:** Copy the updated `openapi.json` from your microservice to the `CommonLibrary/src/main/resources/specs/<service_name>.json` folder.
*   **Regenerate DTOs:** Run `mvn clean install` inside the `CommonLibrary` folder. The `openapi-generator-maven-plugin` configured in the library's `pom.xml` will generate strongly-typed Java DTOs from the spec and install the updated shared library to your local `.m2` repository.
*   **Update Consumer:** In the microservice that needs to call this new API, update its consolidated Feign Client interface to use the newly generated DTOs instead of `Map<String, Object>`. This eliminates duplicate Feign clients across the ecosystem (Phase 3 resolution).

## 6. Frontend Zod Schema & Type Generation

*   **Navigate to UI:** Open a terminal in the `FoodDeliveryAppUI` directory.
*   **Regenerate Schemas:** Run `npm run generate:api`. 
*   **Pipeline Execution:** This invokes the `generate-api-types.sh` script, which sequentially runs TWO generators:
    1.  `openapi-typescript`: Generates raw, monolithic `.d.ts` types for legacy global type imports.
    2.  `openapi-zod-client`: Generates strict runtime Zod schemas and Zodios API clients inside `src/api/generated/schemas/<service>/`. It automatically reads from the committed `openapi.json` specs across all backend folders.

## 7. Frontend API Facade & Chunking Registration

*   **Understand the Chunking Strategy:** To prevent the TypeScript compiler from crashing on massive API specs (`TS2589: Type instantiation is excessively deep`), the `generate:api` script uses the `--group-strategy tag-file` option. This automatically chunks the large `openapi.json` into smaller, individual `.ts` files based on OpenAPI `tags` (which correspond directly to your Spring `@RestController` classes).
*   **Export New Controllers:** If the new API was added to a brand-new controller class, a new chunked file will be generated. You must manually export that new controller in `src/api/generated/schemas/<service>/index.ts` (e.g., `export { NewControllerApi } from "./new-controller";`).
*   **Update Facade:** Manually register the newly chunked controller in the `facade.ts` file using the `mergeApis` utility (e.g., `export const serviceApi = mergeApis({ ...existing, newController: NewControllerApi });`). This unifies the chunked groups back into a single namespaced API client for the UI to consume safely, without overloading the TS compiler.

## 8. Strict Frontend Implementation (Zodios Client)

*   **Import the Facade:** UI components must import the unified Zodios client from the facade (e.g., `import { createApiClient } from '@/api/generated/schemas/customer'`). Do not import raw clients from the chunked files directly.
*   **No String Interpolation (Category 3 Errors):** **Do not** use string interpolation for URLs (e.g., `` api.get(`/api/v1/orders/${id}`) ``). The Zodios static type checker cannot evaluate literal template strings. You must use the strict parameterized path: `api.get('/api/v1/orders/:id', { params: { id } })`.
*   **Use Config Objects (Category 4 Errors):** Ensure all custom headers and query strings are explicitly passed through the `queries` or `headers` config objects in the Zodios call. Zodios will reject runtime parameters that weren't mapped in the Swagger annotations on the backend.

## 9. Handling Extreme TypeScript Edge Cases (Bypasses)

*   **Identify Deep Instantiation Issues:** If the new API introduces infinitely recursive structures or deeply nested generic types (like a nested Spring `Pageable` containing `Map<String, Object>`), it may still trigger `TS2589: Type instantiation is excessively deep and possibly infinite` during UI compilation.
*   **Apply Targeted Bypasses (Phase 9/11):** Resolve this by applying targeted `z.any()` or `z.unknown()` bypasses to the specific schema definitions in the generated frontend code, or via a post-generation patch script. This is an explicit, last-resort escape hatch. **Do not** blindly use `// @ts-expect-error` over the actual `api.get(...)` call, as that masks other valid typings.

## 10. Contract Testing & Public Docs (CI/CD)

*   **Automated Contract Tests (Phase 4):** Ensure the API passes automated Schemathesis (for GET endpoints) or Pact (for POST/PUT consumer-driven endpoints) contract tests during the deployment pipeline. This ensures the live endpoints actually return what `openapi.json` promises, preventing schema drift.
*   **Static HTML Generation (Phase 5):** If the API is exposed externally to 3rd parties (e.g., `PaymentGatewayIntegration` or `ONDCIntegrationService`), verify that the ReDoc pipeline successfully regenerates the static HTML developer portal from the updated `openapi.json`.
