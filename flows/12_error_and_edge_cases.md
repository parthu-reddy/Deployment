# 12. Error & Edge Cases

## 12.1 OTP Rate Limiting

```mermaid
flowchart TD
    A["POST /auth/initiate {phone}"] --> B["Redis: INCR RATELIMIT:INITIATE:{phone}"]
    B --> C{Count > 3 in 10 minutes?}
    C -- Yes --> D["400: Too many login attempts. Try again later"]
    C -- No --> E[Generate and send OTP normally]

    F["POST /auth/verify {phone, otp}"] --> G["Redis: INCR RATELIMIT:VERIFY:{phone}"]
    G --> H{Count > 5 in 5 minutes?}
    H -- Yes --> I["DELETE OTP from Redis (force re-initiate)"]
    I --> J["400: Too many failed attempts. Please request a new OTP"]
    H -- No --> K{OTP correct?}
    K -- Yes --> L[Clear rate limit, proceed with login]
    K -- No --> M["400: Invalid or expired OTP"]
```

## 12.2 JWT Expiration During Active Session

```mermaid
flowchart TD
    A[User makes API call with expired JWT] --> B[API Gateway validates JWT]
    B --> C{Token expired?}
    C -- Yes --> D[Return 401 Unauthorized]
    D --> E[Frontend apiClient interceptor catches 401]
    E --> F[clearToken from localStorage]
    F --> G[Redirect to login screen]
    G --> H[User must re-login via OTP]
```

## 12.3 Session Blacklisted After Device Eviction

```mermaid
flowchart TD
    A[User logs in on 3rd device] --> B[Device limit exceeded]
    B --> C[Evict oldest device session]
    C --> D["Add to Redis BLACKLIST:SESSION:{oldSessionId}"]
    D --> E[Old device makes API call]
    E --> F[Gateway checks Redis blacklist]
    F --> G[Session found in blacklist]
    G --> H[Return 401 Session Revoked]
    H --> I[Old device cleared, redirect to login]
```

## 12.4 Optimistic Locking Conflicts (Order Events)

```mermaid
flowchart TD
    A[Concurrent events for same Order] --> B[Transaction 1: handlePaymentSuccess]
    A --> C[Transaction 2: handleOrderAccepted]
    B --> D[Read Order version N]
    C --> E[Read Order version N]
    D --> F[Update status, save version N+1]
    E --> G["Save version N+1 → OptimisticLockingFailureException!"]
    G --> H{Retry count < MAX_RETRIES?}
    H -- Yes --> I["Sleep(2^retries * 100ms)"]
    I --> J[Re-read Order with new version]
    J --> K[Retry state transition]
    H -- No --> L["CRITICAL: Log error, throw exception"]
    L --> M["Kafka will redeliver message (consumer offset not committed)"]
```

## 12.5 Illegal State Transition

```mermaid
flowchart TD
    A[Event arrives for an Order] --> B[Load current OrderState]
    B --> C[Call handler for event type]
    C --> D{Transition allowed?}
    D -- Yes --> E[Update order status, save]
    D -- No --> F["Throw IllegalStateTransitionException"]
    F --> G["Log: ILLEGAL_STATE_TRANSITION"]
    G --> H[Event silently dropped]
    H --> I[Order state unchanged]

    Note over D: Examples of illegal transitions:
    Note over D: DELIVERED → ACCEPTED
    Note over D: CANCELLED → PAID
    Note over D: READY_FOR_PICKUP → CREATED
```

## 12.6 Payment Webhook Arrives Before Order Exists

```mermaid
flowchart TD
    A[Webhook arrives at PaymentService] --> B[Extract orderId, gatewayOrderId]
    B --> C[Publish to payment-events topic]
    C --> D[CustomerService consumes event]
    D --> E[Find PaymentIntent by gatewayOrderId]
    E --> F{PaymentIntent exists?}
    F -- No --> G["Log: PaymentIntent not found, skip"]
    G --> H[Event dropped — will not be retried]
    F -- Yes --> I[Find Order by internalOrderId]
    I --> J{Order exists?}
    J -- No --> K["Log: Order not found, skip"]
    J -- Yes --> L[Process payment event normally]
```

## 12.7 Restaurant Validation Failures

```mermaid
flowchart TD
    A[Brand Registration Request] --> B{PAN length ≠ 10?}
    B -- Yes --> C["400: Invalid PAN"]
    B -- No --> D{CIN non-empty and length ≠ 21?}
    D -- Yes --> E["400: Invalid CIN"]
    D -- No --> F{GSTIN length ≠ 15?}
    F -- Yes --> G["400: Invalid GSTIN"]
    F -- No --> H{Owner already has brand?}
    H -- Yes --> I["400: Already registered"]
    H -- No --> J{GSTIN already registered?}
    J -- Yes --> K["400: GSTIN in use"]
    J -- No --> L[Success: Save brand]

    M[Outlet Registration Request] --> N{Brand exists?}
    N -- No --> O["404: Brand not found"]
    N -- Yes --> P{FSSAI length ≠ 14?}
    P -- Yes --> Q["400: Invalid FSSAI"]
    P -- No --> R[Success: Save outlet]
```

## 12.8 Network Failure Between Services

```mermaid
flowchart TD
    A[CustomerService calls RestaurantService API] --> B{HTTP call succeeds?}
    B -- Yes --> C[Process response normally]
    B -- No (timeout) --> D[Catch RestClientException]
    D --> E[Return 500 or degraded response]

    F[CustomerService calls PaymentService API] --> G{HTTP call succeeds?}
    G -- Yes --> H[Return payment intent to customer]
    G -- No --> I[Return 500 "Failed to create payment"]
    I --> J[Order saved but no payment intent]
    J --> K[Customer must retry order]

    L[OrderSaga calls PaymentService for refund] --> M{Refund API succeeds?}
    M -- Yes --> N[Update PaymentIntent to REFUNDED]
    M -- No --> O[Set PaymentIntent to REFUND_FAILED]
    O --> P[Requires manual intervention]
```

## 12.9 Kafka Consumer Failure & Redelivery

```mermaid
flowchart TD
    A[Kafka delivers event to consumer] --> B{Processing succeeds?}
    B -- Yes --> C[Commit consumer offset]
    B -- No (exception thrown) --> D[Offset NOT committed]
    D --> E[Kafka redelivers message]
    E --> F{Idempotent check in consumer?}
    F -- Yes --> G[Skip duplicate processing]
    F -- No --> H[Process again — may cause duplicate state changes]
    H --> I[Potential issue: double refund, duplicate order]
```

## 12.10 Gateway Routing — Service Down

```mermaid
flowchart TD
    A[Request arrives at API Gateway] --> B[JWT validated successfully]
    B --> C[Route to downstream service]
    C --> D{Downstream healthy?}
    D -- Yes --> E[Forward and return response]
    D -- No --> F[Connection refused / timeout]
    F --> G[Gateway returns 503 Service Unavailable]
    G --> H[Frontend shows error toast]
```

## 12.11 Concurrent Device Login (Same Device ID)

```mermaid
flowchart TD
    A["Login on Device A (deviceId: ABC)"] --> B[Session 1 created for ABC]
    B --> C["Login again on same device (deviceId: ABC)"]
    C --> D[Find existing device with same deviceId]
    D --> E[Revoke Session 1]
    E --> F[Blacklist Session 1 in Redis]
    F --> G[Create Session 2 for ABC]
    G --> H[Any request with Session 1 token → 401]
```

## 12.12 Frontend 401/403 Auto-Logout

```mermaid
flowchart TD
    A[API response received by apiClient.ts] --> B{Status code?}
    B -- 401 --> C[Token expired or invalid]
    C --> D[clearToken from memory + localStorage]
    D --> E[window.location = login page]
    B -- 403 --> F[Insufficient permissions]
    F --> D
    B -- 200-399 --> G[Return response normally]
    B -- 400 --> H[Return error for UI handling]
    B -- 500+ --> I[Show server error toast]
```

## 12.13 Stale Config Server Data

```mermaid
flowchart TD
    A[Service starts up] --> B[Connect to ConfigService :8888]
    B --> C{Config server available?}
    C -- Yes --> D[Fetch application properties]
    D --> E[Bootstrap with remote config]
    C -- No --> F[Use local fallback application.yml]
    F --> G[Start with local defaults]
    G --> H[Log warning: config server unavailable]
```

## 12.14 IDOR Protection on Driver Telemetry

```mermaid
flowchart TD
    A["POST /api/v1/delivery/telemetry/batch"] --> B[Extract authId from principal]
    B --> C[Iterate over telemetry events]
    C --> D{event.driverId == authId?}
    D -- No --> E["Log: Unauthorized telemetry push attempt"]
    E --> F[Skip event (IDOR prevented)]
    D -- Yes --> G[Process event normally]
    G --> H[Update Redis geospatial index]
```

## 12.15 Customer Auto-Creation on First Address

```mermaid
flowchart TD
    A["POST /api/v1/customers/{id}/addresses"] --> B[Check customerRepository.existsById]
    B --> C{Customer exists?}
    C -- No --> D["Auto-create default Customer entity (name: 'Customer', phone: '0000000000')"]
    D --> E[Save to DB]
    C -- Yes --> E
    E --> F[Create CustomerAddress]
    F --> G[Save Address to DB]
    G --> H[Return 200 OK]
```

## 12.16 Delivery Partner Unavailable Fallback

```mermaid
flowchart TD
    A[Customer requests delivery availability check] --> B[Fetch restaurant coordinates]
    B --> C[Call MapsIntegration /api/fleet/availability/check]
    C --> D{Is driver available in radius?}
    D -- Yes --> E[Return true]
    D -- No --> F["Throw DeliveryPartnerUnavailableException"]
    F --> G["API Gateway returns 400 Bad Request"]
    G --> H["UI prevents user from placing order from this restaurant"]
```

## 12.17 UI Profile Name Enforcement

```mermaid
flowchart TD
    A[User completes OTP Login] --> B[UI checks if profile.name is empty]
    B --> C{Name empty?}
    C -- Yes --> D[Show NamePromptModal (background blurred)]
    D --> E[User enters name and submits]
    E --> F["PUT /api/v1/users/profile/name"]
    F --> G[Save profile in localStorage]
    G --> H[Unlock dashboard]
    C -- No --> H
```
