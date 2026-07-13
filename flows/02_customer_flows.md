# 2. Customer Flows

## 2.1 Address Management — Add Address

```mermaid
sequenceDiagram
    participant U as Customer
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant CS as CustomerService
    participant MI as MapsIntegration

    U->>UI: Click "Add Address"
    UI->>UI: Open AddressSelectionModal
    U->>UI: Start typing address
    UI->>GW: GET /api/places/autocomplete?input={query}
    GW->>MI: Forward to MapsIntegration
    MI->>MI: Query Google Places API
    MI-->>GW: [{description, placeId, lat, lng}, ...]
    GW-->>UI: Autocomplete suggestions
    UI-->>U: Show dropdown suggestions

    U->>UI: Select a suggestion
    UI->>UI: Auto-fill lat/lng from selection
    U->>UI: Fill label (Home/Work/Other), address details
    U->>UI: Click "Save Address"
    UI->>GW: POST /api/v1/customers/{customerId}/addresses {label, addressLine1, city, state, zip, lat, lng}
    GW->>CS: Forward (X-User-Id verified)
    CS->>CS: Check if Customer entity exists
    alt Customer not in DB
        CS->>CS: Auto-create Customer record
    end
    CS->>CS: Save CustomerAddress to DB
    CS-->>GW: 200 {addressDto}
    GW-->>UI: 200
    UI-->>U: Show saved address in list
```

## 2.2 Address Management — Delete Address

```mermaid
sequenceDiagram
    participant U as Customer
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant CS as CustomerService

    U->>UI: Click delete on an address
    UI->>GW: DELETE /api/v1/customers/{customerId}/addresses/{addressId}
    GW->>CS: Forward (RBAC: CUSTOMER + ownership check)
    CS->>CS: Delete address by id + customerId
    CS-->>GW: 200 "Address deleted"
    GW-->>UI: 200
    UI-->>U: Remove from UI list
```

## 2.3 Address Management — List Addresses

```mermaid
sequenceDiagram
    participant U as Customer
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant CS as CustomerService

    U->>UI: Open address page
    UI->>GW: GET /api/v1/customers/{customerId}/addresses
    GW->>CS: Forward
    CS->>CS: Query addresses by customerId
    CS-->>GW: 200 [addresses]
    GW-->>UI: 200
    UI-->>U: Display address list with labels
```

## 2.4 Restaurant Discovery — Browse Nearby

```mermaid
sequenceDiagram
    participant U as Customer
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant CS as CustomerService
    participant RS as RestaurantService

    U->>UI: Select delivery address
    UI->>UI: Extract lat/lng from selected address
    UI->>GW: GET /api/v1/customers/restaurants/nearby?lat={lat}&lng={lng}&radiusKm=5
    Note over GW: Public GET endpoint — no auth required
    GW->>CS: Forward
    CS->>RS: HTTP GET /api/v1/restaurants/nearby?lat=&lng=&radiusKm=
    RS->>RS: PostGIS spatial query within radius
    RS-->>CS: [{outlet details with distance}]
    CS-->>GW: 200 [restaurants]
    GW-->>UI: 200
    UI-->>U: Display restaurant cards with distance
```

## 2.5 Restaurant Discovery — View Menu (Effective Catalog)

```mermaid
sequenceDiagram
    participant U as Customer
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService

    U->>UI: Click on a restaurant card
    UI->>GW: GET /api/v1/restaurants/{outletId}/catalog/items
    Note over GW: Public GET endpoint
    GW->>RS: Forward
    RS->>RS: Fetch master menu items for brand
    RS->>RS: Apply outlet-specific overrides (price, availability)
    RS->>RS: Build effective catalog
    RS-->>GW: 200 [effectiveMenuItems]
    GW-->>UI: 200
    UI-->>U: Display menu with categories, prices, veg/non-veg badges
```

## 2.6 Cart Management

```mermaid
flowchart TD
    A[Customer views restaurant menu] --> B{Add item to cart?}
    B -- Yes --> C[UI: Add item to local cart state]
    C --> D[Show cart drawer with items]
    D --> E{Modify quantity?}
    E -- Increase --> F[Increment item quantity]
    E -- Decrease --> G{Quantity > 1?}
    G -- Yes --> H[Decrement quantity]
    G -- No --> I[Remove item from cart]
    E -- No changes --> J{Ready to order?}
    F --> J
    H --> J
    I --> J
    B -- No --> J
    J -- Yes --> K[Click "Place Order"]
    J -- No --> L[Continue browsing]
    K --> M{Delivery address selected?}
    M -- No --> N[Prompt to select address]
    N --> O[Open AddressSelectionModal]
    O --> M
    M -- Yes --> P[Proceed to create order]
```

## 2.7 Place Order (Full Flow)

```mermaid
sequenceDiagram
    participant U as Customer
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant CS as CustomerService
    participant OS as OrderSagaOrchestrator
    participant PS as PaymentService
    participant KF as Kafka

    U->>UI: Click "Place Order" with cart items
    UI->>GW: POST /api/v1/orders {restaurantId, deliveryAddressId, items[{menuItemId, qty}]}
    GW->>CS: Forward (RBAC: CUSTOMER)
    CS->>CS: Resolve delivery address from addressId
    CS->>CS: Fetch menu item prices from RestaurantService
    CS->>CS: Calculate totalAmount
    CS->>OS: startOrderSaga(order)
    OS->>OS: Save Order to DB (status: CREATED)
    OS->>OS: Save OrderCreatedEvent to Outbox
    Note over OS: Outbox poller publishes to Kafka

    CS->>PS: POST /api/v1/payments/create-order {internalOrderId, amount, gateway}
    PS->>PS: Call payment gateway API (Razorpay/Cashfree/Vyapar)
    PS->>PS: Save PaymentIntent to DB
    PS-->>CS: 200 {gatewayOrderId}
    CS->>CS: Save PaymentIntent locally (internalOrderId ↔ gatewayOrderId)

    CS-->>GW: 200 {order, paymentIntent: {gatewayOrderId, gateway}}
    GW-->>UI: 200
    UI-->>U: Open Payment Modal with gateway info
    U->>UI: Complete payment on gateway UI
    Note over UI,PS: Gateway sends webhook (see Payment Flows)
```

## 2.8 Delay Approval (Customer Responds to Restaurant Delay Request)

```mermaid
sequenceDiagram
    participant U as Customer
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant CS as CustomerService
    participant OS as OrderSagaOrchestrator
    participant KF as Kafka

    Note over U: Customer receives push notification about delay
    U->>UI: Open order details
    UI-->>U: Show delay request modal (X minutes delay)

    alt Customer approves delay
        U->>UI: Click "Approve"
        UI->>GW: POST /api/v1/orders/{orderId}/delay-approval {approved: true}
        GW->>CS: Forward (RBAC: CUSTOMER + ownership)
        CS->>OS: publishDelayApprovalEvent(order, true)
        OS->>OS: Save ORDER_DELAY_APPROVED to Outbox
        OS-->>CS: Done
        CS-->>GW: 200
        GW-->>UI: 200
        UI-->>U: Show "Delay approved" confirmation
    else Customer rejects delay
        U->>UI: Click "Reject"
        UI->>GW: POST /api/v1/orders/{orderId}/delay-approval {approved: false}
        GW->>CS: Forward
        CS->>OS: publishDelayApprovalEvent(order, false)
        OS->>OS: Save ORDER_DELAY_REJECTED to Outbox
        Note over OS: This triggers order cancellation flow
        CS-->>GW: 200
        GW-->>UI: 200
        UI-->>U: Show "Order will be cancelled"
    end
```

## 2.9 Delay Approval Timeout (Auto-Cancel)

```mermaid
flowchart TD
    A["Scheduler runs every 60 seconds"] --> B["Query orders with status AWAITING_DELAY_APPROVAL"]
    B --> C{"Any orders older than 10 minutes?"}
    C -- No --> D[Sleep until next run]
    C -- Yes --> E["For each timed-out order"]
    E --> F["Publish ORDER_DELAY_REJECTED event"]
    F --> G["Reason: Auto-cancelled - Customer did not respond in 10 minutes"]
    G --> H["Order enters cancellation + refund flow"]
    H --> D
```

## 2.10 Live Order Tracking (SSE)

```mermaid
sequenceDiagram
    participant U as Customer
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant CS as CustomerService
    participant RD as Redis

    U->>UI: View active order page
    UI->>GW: GET /api/v1/orders/{orderId}/tracking (Accept: text/event-stream)
    GW->>CS: Forward SSE connection
    CS->>CS: Open SseEmitter
    loop Polling Redis for updates
        CS->>RD: Subscribe to order:{orderId} channel
        RD-->>CS: Order status/location update
        CS-->>GW: SSE event {status, driverLat, driverLng, eta}
        GW-->>UI: SSE event
        UI-->>U: Update map + status indicator
    end
    Note over U: Connection stays open until order delivered or closed
```

## 2.11 Delivery Availability Check

```mermaid
sequenceDiagram
    participant U as Customer
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant CS as CustomerService

    U->>UI: View restaurant detail page
    UI->>GW: GET /api/v1/customers/restaurants/{id}/delivery-availability?customerLat=&customerLng=
    GW->>CS: Forward
    CS->>CS: Check distance, restaurant open hours, delivery radius
    CS-->>GW: 200 {deliverable: true/false, estimatedDeliveryTime: "30-40 mins"}
    GW-->>UI: 200
    UI-->>U: Show delivery estimate or "Not deliverable" badge
```
