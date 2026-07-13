# 3. Restaurant Onboarding Flows

## 3.1 Brand Registration (Happy Path)

```mermaid
sequenceDiagram
    participant U as Restaurant Owner
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService

    U->>UI: Navigate to Restaurant Portal
    UI-->>U: Show "Register New Brand" button
    U->>UI: Click "Register New Brand"
    UI-->>U: Show brand registration form
    U->>UI: Fill: name, GSTIN, PAN, bank account, IFSC
    U->>UI: Click "Register Brand"
    UI->>GW: POST /api/v1/brands {name, gstin, pan, cin, bankAccountNumber, ifscCode, logoUrl}
    GW->>RS: Forward (RBAC: RESTAURANT, X-User-Id injected)
    RS->>RS: Extract ownerId from X-User-Id header
    RS->>RS: Validate PAN (10 chars)
    RS->>RS: Validate CIN (21 chars, if provided)
    RS->>RS: Validate GSTIN format
    RS->>RS: Create Brand entity with ownerId
    RS->>RS: Save to DB
    RS-->>GW: 200 {brand}
    GW-->>UI: 200
    UI-->>U: Hide form, show brand in list
    UI->>UI: Refresh brand/outlet data
```

## 3.2 Duplicate Brand Prevention — Same Owner

```mermaid
sequenceDiagram
    participant U as Restaurant Owner
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService

    U->>UI: Click "Register New Brand" (already has one)
    U->>UI: Fill form and submit
    UI->>GW: POST /api/v1/brands {...}
    GW->>RS: Forward
    RS->>RS: Check brandRepository.existsByOwnerId(ownerId)
    RS-->>GW: 400 "You have already registered a brand"
    GW-->>UI: HTTP 400
    UI-->>U: Show error "Brand registration failed. You may have already registered a brand"
```

## 3.3 Duplicate Brand Prevention — Same GSTIN

```mermaid
sequenceDiagram
    participant U as New Owner
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService

    U->>UI: Register brand with existing GSTIN
    UI->>GW: POST /api/v1/brands {gstin: "existing-gstin", ...}
    GW->>RS: Forward
    RS->>RS: existsByOwnerId → false (new owner)
    RS->>RS: findByGstin("existing-gstin") → FOUND
    RS-->>GW: 400 "A brand with this GSTIN is already registered"
    GW-->>UI: HTTP 400
    UI-->>U: Show error "GSTIN already in use"
```

## 3.4 Brand Registration Validation Failures

```mermaid
flowchart TD
    A[Submit brand registration] --> B{PAN provided and length ≠ 10?}
    B -- Yes --> C["400: Invalid PAN. Must be 10 characters"]
    B -- No --> D{CIN provided, non-empty, and length ≠ 21?}
    D -- Yes --> E["400: Invalid CIN. Must be 21 characters"]
    D -- No --> F{GSTIN provided and length ≠ 15?}
    F -- Yes --> G["400: Invalid GSTIN. Must be 15 characters"]
    F -- No --> H[Validation passed — save brand]
```

## 3.5 Outlet Registration

```mermaid
sequenceDiagram
    participant U as Restaurant Owner
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService

    U->>UI: Click "Add Outlet" under brand
    UI-->>U: Show outlet registration form
    U->>UI: Fill: name, FSSAI license, location (lat/lng), opening/closing time
    U->>UI: Click "Register Outlet"
    UI->>GW: POST /api/v1/brands/{brandId}/outlets {name, fssaiLicenseNumber, lat, lng, openingTime, closingTime}
    GW->>RS: Forward (RBAC: RESTAURANT)
    RS->>RS: Validate brand exists
    RS->>RS: Validate FSSAI (14 chars)
    RS->>RS: Create Outlet with PostGIS Point(lng, lat)
    RS->>RS: Save to DB
    RS-->>GW: 200 {outlet}
    GW-->>UI: 200
    UI-->>U: Show outlet in list, enable menu management
```

## 3.6 View Brands for Logged-In Owner

```mermaid
sequenceDiagram
    participant U as Restaurant Owner
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService

    U->>UI: Login as restaurant user
    UI->>GW: GET /api/v1/brands (with Authorization header)
    GW->>RS: Forward (X-User-Id injected)
    RS->>RS: Query brandRepository.findByOwnerId(userId)
    RS-->>GW: 200 [brands]
    GW-->>UI: 200
    UI-->>U: Show brand cards
    Note over UI: If no brands, show registration form
```

## 3.7 View Outlets for a Brand

```mermaid
sequenceDiagram
    participant U as Restaurant Owner
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService

    UI->>GW: GET /api/v1/brands/{brandId}/outlets
    GW->>RS: Forward
    RS->>RS: Query outletRepository.findByBrandId(brandId)
    RS-->>GW: 200 [outlets]
    GW-->>UI: 200
    UI-->>U: Show outlet selector dropdown
```

## 3.8 Master Menu Item Creation

```mermaid
sequenceDiagram
    participant U as Restaurant Owner
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService

    U->>UI: Open Menu Editor > Master Menu tab
    U->>UI: Fill: dish name, base price, prep time, category, description, veg/non-veg
    U->>UI: Click "Add Master Item"
    UI->>GW: POST /api/v1/brands/{brandId}/master-menu {name, basePrice, defaultPrepTimeMinutes, imageUrl, category, description, isVeg}
    GW->>RS: Forward (RBAC: RESTAURANT)
    RS->>RS: Validate brand exists
    RS->>RS: Create MasterMenuItem
    RS->>RS: Save to DB
    RS-->>GW: 200 {masterMenuItem}
    GW-->>UI: 200
    UI->>UI: Refresh master menu list
    UI-->>U: Show new item in catalog
```

## 3.9 Outlet Menu Override

```mermaid
sequenceDiagram
    participant U as Restaurant Owner
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService

    U->>UI: Open Menu Editor > Override tab
    U->>UI: Select master item, set custom price and/or toggle availability
    U->>UI: Click "Save Override"
    UI->>GW: POST /api/v1/outlets/{outletId}/menu-overrides/{masterMenuItemId} {price, active}
    GW->>RS: Forward (RBAC: RESTAURANT)
    RS->>RS: Find or create OutletMenuOverride
    RS->>RS: Update price/availability
    RS->>RS: Save to DB
    RS-->>GW: 200 {override}
    GW-->>UI: 200
    UI->>UI: Refresh effective menu
    UI-->>U: Show updated catalog with overrides applied
```

## 3.10 View Effective Menu (What Customers See)

```mermaid
flowchart TD
    A[Fetch effective catalog for outlet] --> B[Load all MasterMenuItems for brand]
    B --> C[Load all OutletMenuOverrides for outlet]
    C --> D{For each master item}
    D --> E{Has outlet override?}
    E -- Yes --> F[Apply overridden price]
    F --> G{Override marks item inactive?}
    G -- Yes --> H[Exclude from effective menu]
    G -- No --> I[Include with overridden price]
    E -- No --> J[Include with base price from master]
    I --> K[Return combined effective menu]
    J --> K
    H --> K
```
