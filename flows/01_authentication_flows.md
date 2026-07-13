# 1. Authentication Flows

## 1.1 Login (OTP Initiation + Verification)

```mermaid
sequenceDiagram
    participant U as User (Browser)
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant IS as IdentityService
    participant RD as Redis
    participant KF as Kafka
    participant NS as NotificationService

    Note over U,NS: === OTP Initiation ===
    U->>UI: Enter phone number + select portal
    UI->>GW: POST /api/v1/internal/auth/initiate {phone, serviceName}
    Note over GW: Public endpoint, no JWT required
    GW->>IS: Forward request
    IS->>RD: INCREMENT RATELIMIT:INITIATE:{phone} (TTL 10min)
    alt Rate limit exceeded (>3 attempts)
        IS-->>GW: 400 "Too many login attempts"
        GW-->>UI: 400
        UI-->>U: Show rate limit error
    else Within rate limit
        IS->>IS: Generate 6-digit OTP
        IS->>RD: PUT OTP:{phone}:{service} = otp (TTL 5min)
        IS->>KF: Publish NotificationEvent (phone, SMS, otp)
        KF->>NS: Consume notification-dispatch topic
        NS->>NS: Route to SMS provider (Exotel/Twilio)
        IS-->>GW: 200 {otp} (returned for dev/debug)
        GW-->>UI: 200
        UI-->>U: Show OTP input field
    end

    Note over U,NS: === OTP Verification ===
    U->>UI: Enter OTP
    UI->>GW: POST /api/v1/internal/auth/verify {phone, otp, serviceName, deviceId, deviceModel}
    GW->>IS: Forward request
    IS->>RD: INCREMENT RATELIMIT:VERIFY:{phone} (TTL 5min)
    alt Brute force detected (>5 attempts)
        IS->>RD: DELETE OTP:{phone}:{service}
        IS-->>GW: 400 "Too many failed attempts"
        GW-->>UI: 400
        UI-->>U: Show brute force error
    else Within limit
        IS->>RD: GET OTP:{phone}:{service}
        alt OTP matches
            IS->>RD: DELETE OTP:{phone}:{service}
            IS->>RD: DELETE RATELIMIT:VERIFY:{phone}
            IS->>IS: Find or create AppUser
            IS->>IS: Assign default role based on portal
            IS->>IS: Handle device registration (see 1.3)
            IS->>IS: Generate RS256 JWT token
            IS-->>GW: 200 {token}
            GW-->>UI: 200
            UI->>UI: setToken(token), setUserProfile(decoded)
            UI->>UI: Store in localStorage
            UI-->>U: Navigate to role-specific dashboard
        else OTP does not match
            IS-->>GW: 400 "Invalid or expired OTP"
            GW-->>UI: 400
            UI-->>U: Show "Invalid OTP" error
        end
    end
```

## 1.2 Hard Refresh / Session Restoration

```mermaid
flowchart TD
    A[User hard-refreshes browser] --> B[App.tsx useEffect runs]
    B --> C{getToken from localStorage?}
    C -- No token --> Z[Show Landing/Login screen]
    C -- Token exists --> D[getUserProfile]
    D --> E{memoryProfile exists?}
    E -- Yes --> F[Use in-memory profile]
    E -- No --> G{user_profile in localStorage?}
    G -- Yes --> H[Parse JSON, set memoryProfile]
    G -- No --> I[Decode JWT token]
    I --> J{JWT has 'roles' array?}
    J -- Yes --> K["Extract roles[0].toLowerCase()"]
    J -- No --> L["Fallback: decoded.role || 'customer'"]
    K --> M[Create profile object]
    L --> M
    M --> N[Save to memoryProfile + localStorage]
    H --> O[Set role, phone, userName from profile]
    F --> O
    N --> O
    O --> P[Fetch /api/v1/users/profile for latest name]
    P --> Q{API call succeeds?}
    Q -- Yes --> R[Update userName if returned]
    Q -- No 401/403 --> S[clearToken, redirect to login]
    Q -- Other error --> T[Keep existing profile]
    R --> U[Render role-specific dashboard]
    T --> U
```

## 1.3 Device Management (Max 2 Devices)

```mermaid
flowchart TD
    A[User verifies OTP successfully] --> B{Same deviceId already registered?}
    B -- Yes --> C[Revoke existing session for that device]
    C --> D[Remove old UserDevice from DB]
    D --> E[BLACKLIST:SESSION:{oldSessionId} in Redis]
    E --> F{Active devices >= 2?}
    B -- No --> F
    F -- Yes --> G[Evict oldest device]
    G --> H[Remove oldest UserDevice from DB]
    H --> I[BLACKLIST:SESSION:{oldestSessionId} in Redis]
    I --> J[Save new UserDevice]
    F -- No --> J
    J --> K[Generate JWT with new sessionId]
    K --> L[Return JWT token]
```

## 1.4 Logout (Single Device)

```mermaid
sequenceDiagram
    participant U as User
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant IS as IdentityService
    participant RD as Redis

    U->>UI: Click Logout
    UI->>GW: POST /api/v1/internal/auth/logout {sessionId}
    GW->>IS: Forward (X-User-Id from JWT)
    IS->>IS: Find UserDevice by sessionId
    alt Device belongs to user
        IS->>IS: Delete UserDevice from DB
        IS->>RD: PUT BLACKLIST:SESSION:{sessionId} = "revoked" (TTL = jwt expiration)
        IS-->>GW: 200 OK
    else Device not found or wrong user
        IS-->>GW: 200 OK (no-op)
    end
    GW-->>UI: 200
    UI->>UI: clearToken(), clear localStorage
    UI-->>U: Redirect to login screen
```

## 1.5 Logout All Devices

```mermaid
sequenceDiagram
    participant U as User
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant IS as IdentityService
    participant RD as Redis

    U->>UI: Click "Logout All Devices"
    UI->>GW: DELETE /api/v1/internal/auth/devices {serviceName}
    GW->>IS: Forward (X-User-Id, X-Session-Id)
    IS->>IS: Find all UserDevices for user + portal
    loop Each device
        IS->>RD: PUT BLACKLIST:SESSION:{sessionId} = "revoked"
    end
    IS->>IS: Delete all UserDevices from DB
    IS-->>GW: 200 OK
    GW-->>UI: 200
    UI->>UI: clearToken(), clear localStorage
    UI-->>U: Redirect to login screen
```

## 1.6 Revoke Specific Device

```mermaid
sequenceDiagram
    participant U as User
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant IS as IdentityService
    participant RD as Redis

    U->>UI: Click revoke on a specific device
    UI->>GW: DELETE /api/v1/internal/auth/devices/{sessionId}
    GW->>IS: Forward (X-User-Id)
    IS->>IS: Find UserDevice by sessionId
    alt Device belongs to user
        IS->>IS: Delete UserDevice from DB
        IS->>RD: PUT BLACKLIST:SESSION:{sessionId} = "revoked"
        IS-->>GW: 200 OK
    else Not found
        IS-->>GW: 200 OK (no-op)
    end
    GW-->>UI: 200
    UI-->>U: Refresh device list
```

## 1.7 View Active Devices

```mermaid
sequenceDiagram
    participant U as User
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant IS as IdentityService

    U->>UI: Open Profile/Devices panel
    UI->>GW: GET /api/v1/internal/auth/devices?serviceName={portal}
    GW->>IS: Forward (X-User-Id)
    IS->>IS: Query UserDevices for userId + portal
    IS-->>GW: 200 [{sessionId, deviceId, deviceModel, loginTime}, ...]
    GW-->>UI: 200
    UI-->>U: Display active devices list
```

## 1.8 Profile Update (Name)

```mermaid
sequenceDiagram
    participant U as User
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant IS as IdentityService

    U->>UI: Enter new name in profile modal
    UI->>GW: PUT /api/v1/users/profile/name {name}
    GW->>IS: Forward (X-User-Id from JWT)
    IS->>IS: Find AppUser by userId
    alt User found
        IS->>IS: Update user.name
        IS->>IS: Save to DB
        IS-->>GW: 200 "Name updated"
    else User not found
        IS-->>GW: 400 "User not found"
    end
    GW-->>UI: 200
    UI->>UI: Update local userName state
    UI-->>U: Show success feedback
```

## 1.9 Internal Role Management (Service-to-Service)

```mermaid
flowchart TD
    A["POST /api/v1/internal/users/{id}/roles {roleName}"] --> B[Extract X-Calling-Service header]
    B --> C[Validate calling service]
    C --> D[Find AppUser by id]
    D --> E{User found?}
    E -- No --> F["404: User not found"]
    E -- Yes --> G[Check if user already has role for calling service]
    G --> H{Has role?}
    H -- Yes --> I["200 OK (no-op)"]
    H -- No --> J[Create UserRole entity]
    J --> K[Save to DB]
    K --> L["200: Role added successfully"]
```
