# 8. API Gateway Flows

## 8.1 Request Processing Pipeline

```mermaid
flowchart TD
    A[HTTP Request arrives at Gateway :3000] --> B{Path matches public whitelist?}
    B -- Yes --> C[Forward directly to downstream service]
    B -- No --> D{Authorization header present?}
    D -- No --> E[Return 401 Unauthorized]
    D -- Yes --> F[Extract JWT from Bearer token]
    F --> G{JWT signature valid? RS256}
    G -- No --> H[Return 401 Invalid Token]
    G -- Yes --> I{Token expired?}
    I -- Yes --> J[Return 401 Token Expired]
    I -- No --> K[Extract sessionId from JWT claims]
    K --> L{sessionId in Redis BLACKLIST?}
    L -- Yes --> M[Return 401 Session Revoked]
    L -- No --> N[Extract userId, roles from JWT]
    N --> O[Inject X-User-Id header]
    O --> P[Inject X-Session-Id header]
    P --> Q[Inject X-User-Roles header]
    Q --> R{Route-specific role check?}
    R -- Yes --> S{User has required role?}
    S -- Yes --> T[Forward to downstream service]
    S -- No --> U[Return 403 Forbidden]
    R -- No --> T
```

## 8.2 Public Endpoint Whitelist

```mermaid
flowchart LR
    A[Public Endpoints] --> B["/api/v1/internal/auth/**"]
    A --> C["/api/v1/webhooks/**"]
    A --> D["/api/v1/restaurants/nearby"]
    A --> E["GET /api/v1/restaurants/{id}"]
    A --> F["GET /api/v1/restaurants/{id}/catalog/items"]
    A --> G["/api/places/**"]
    A --> H["/api/v1/restaurants/{id}/menu/batch"]
    A --> I["/api/config/**"]
```

## 8.3 Role-Based Route Enforcement

```mermaid
flowchart TD
    A[Request with valid JWT] --> B{Target path?}
    B -->|"/api/v1/orders/**"| C{Role: CUSTOMER?}
    C -- Yes --> D[Forward to CustomerService]
    C -- No --> E[403 Forbidden]
    B -->|"/api/v1/brands/**"| F{Role: RESTAURANT?}
    F -- Yes --> G[Forward to RestaurantService]
    F -- No --> H[403 Forbidden]
    B -->|"/api/delivery/**"| I{Role: DELIVERY?}
    I -- Yes --> J[Forward to DeliveryService]
    I -- No --> K[403 Forbidden]
    B -->|"/api/v1/payments/**"| L{Authenticated?}
    L -- Yes --> M[Forward to PaymentService]
    L -- No --> N[401 Unauthorized]
    B -->|"/api/v1/users/**"| O{Authenticated?}
    O -- Yes --> P[Forward to IdentityService]
    O -- No --> Q[401 Unauthorized]
```

## 8.4 Session Blacklist Check Detail

```mermaid
sequenceDiagram
    participant GW as API Gateway
    participant RD as Redis

    GW->>GW: Extract sessionId from JWT claims
    GW->>RD: EXISTS BLACKLIST:SESSION:{sessionId}
    alt Key exists (session revoked)
        RD-->>GW: 1
        GW-->>GW: Return 401 "Session has been revoked"
    else Key not found (session valid)
        RD-->>GW: 0
        GW-->>GW: Continue processing
    end
```

## 8.5 Service Routing Table

```mermaid
flowchart TD
    A[Gateway Routes] --> B["/api/v1/internal/**" → IdentityService :8091]
    A --> C["/api/v1/users/**" → IdentityService :8091]
    A --> D["/api/v1/customers/**" → CustomerService :8093]
    A --> E["/api/v1/orders/**" → CustomerService :8093]
    A --> F["/api/v1/brands/**" → RestaurantService :8094]
    A --> G["/api/v1/restaurants/**" → RestaurantService :8094]
    A --> H["/api/v1/outlets/**" → RestaurantService :8094]
    A --> I["/api/delivery/**" → DeliveryService :8095]
    A --> J["/api/v1/payments/**" → PaymentService :8096]
    A --> K["/api/v1/webhooks/**" → PaymentService :8096]
    A --> L["/api/places/**" → CustomerService :8093 → MapsIntegration :8097]
    A --> M["/api/fleet/**" → MapsIntegration :8097]
    A --> N["/api/logistics/**" → MapsIntegration :8097]
```
