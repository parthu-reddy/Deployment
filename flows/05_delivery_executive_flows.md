# 5. Delivery Executive Flows

## 5.1 Driver Onboarding

```mermaid
sequenceDiagram
    participant U as Delivery Executive
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant DS as DeliveryService

    U->>UI: Login as delivery executive
    UI-->>U: Show onboarding form
    U->>UI: Fill: name, phone, vehicle number, photo URL
    U->>UI: Click "Register"
    UI->>GW: POST /api/delivery/onboard {name, phoneNumber, vehicleNumber, photoUrl}
    GW->>DS: Forward (RBAC: DELIVERY, principal = userId)
    DS->>DS: Create DeliveryExecutive entity
    DS->>DS: Set status = OFFLINE
    DS->>DS: Save to DB
    DS-->>GW: 200 {deliveryExecutive}
    GW-->>UI: 200
    UI-->>U: Navigate to delivery dashboard
```

## 5.2 Toggle Availability

```mermaid
sequenceDiagram
    participant U as Delivery Executive
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant DS as DeliveryService
    participant MI as MapsIntegration

    U->>UI: Toggle "Go Online" / "Go Offline"
    UI->>GW: POST /api/delivery/status {driverId, available: true/false}
    GW->>DS: Forward (RBAC: DELIVERY, ownership check)
    DS->>DS: Update DeliveryExecutive status
    alt Going Online
        DS->>DS: Set status = AVAILABLE
        DS->>MI: POST /api/fleet/availability {driverId, available: true, lat, lng}
        MI->>MI: Add driver to available fleet pool
    else Going Offline
        DS->>DS: Set status = OFFLINE
        DS->>MI: POST /api/fleet/availability {driverId, available: false}
        MI->>MI: Remove driver from available pool
    end
    DS-->>GW: 200
    GW-->>UI: 200
    UI-->>U: Update status indicator
```

## 5.3 Order Dispatch — Finding a Driver

```mermaid
sequenceDiagram
    participant KF as Kafka (order-events)
    participant DS as DeliveryService
    participant MI as MapsIntegration
    participant DB as Delivery DB

    KF->>DS: ORDER_ACCEPTED event {orderId, restaurantId, deliveryLat, deliveryLng}
    DS->>DS: DeliveryEventStrategy: OrderAcceptedStrategy
    DS->>MI: POST /api/logistics/dispatch {restaurantLat, restaurantLng, deliveryLat, deliveryLng}
    MI->>MI: Find nearby available drivers (spatial query)
    MI->>MI: Calculate ETAs for each candidate
    MI->>MI: Rank by proximity + rating
    alt Candidates found
        MI-->>DS: {candidateDriverId, eta}
        DS->>DB: Create delivery assignment (orderId, driverId, status: PINGED)
        DS->>KF: Publish DISPATCH_CANDIDATE_FOUND {orderId, driverId}
        Note over DS: Driver now has 30s to accept
    else No drivers available
        MI-->>DS: 404 No candidates
        DS->>KF: Publish DISPATCH_FAILED {orderId}
    end
```

## 5.4 Driver Accepts Order Ping

```mermaid
sequenceDiagram
    participant U as Driver
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant DS as DeliveryService
    participant KF as Kafka

    Note over U: Driver receives order ping notification
    U->>UI: Click "Accept" on order ping
    UI->>GW: POST /api/delivery/drivers/{driverId}/orders/{orderId}/accept
    GW->>DS: Forward (RBAC: DELIVERY + ownership)
    DS->>DS: Update assignment status = ASSIGNED
    DS->>DS: Update driver status = ON_DELIVERY
    DS->>KF: Publish DRIVER_ASSIGNED {orderId, driverId, eta}
    DS-->>GW: 200
    GW-->>UI: 200
    UI-->>U: Show pickup navigation
```

## 5.5 Driver Rejects Order Ping

```mermaid
sequenceDiagram
    participant U as Driver
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant DS as DeliveryService
    participant KF as Kafka

    U->>UI: Click "Reject" on order ping
    UI->>GW: POST /api/delivery/drivers/{driverId}/orders/{orderId}/reject
    GW->>DS: Forward
    DS->>DS: Mark assignment as REJECTED
    DS->>DS: Set driver back to AVAILABLE
    DS->>KF: Publish ORDER_DRIVER_REJECTED {orderId, driverId}
    Note over DS: System will try to find next driver
    DS-->>GW: 200
    GW-->>UI: 200
    UI-->>U: Return to waiting screen
```

## 5.6 Driver Ping Timeout

```mermaid
sequenceDiagram
    participant U as Driver
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant DS as DeliveryService
    participant KF as Kafka

    Note over U: 30 seconds pass without accept/reject
    UI->>GW: POST /api/delivery/drivers/{driverId}/orders/{orderId}/timeout
    GW->>DS: Forward
    DS->>DS: Mark assignment as TIMED_OUT
    DS->>DS: Set driver back to AVAILABLE
    DS->>KF: Publish ORDER_DRIVER_REJECTED {orderId, driverId, reason: TIMEOUT}
    Note over DS: System attempts next candidate
    DS-->>GW: 200
    GW-->>UI: 200
    UI-->>U: Ping dismissed
```

## 5.7 Driver Updates Order Status (Pickup → Delivery)

```mermaid
sequenceDiagram
    participant U as Driver
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant DS as DeliveryService
    participant KF as Kafka

    Note over U: Driver arrives at restaurant
    U->>UI: Click "Picked Up"
    UI->>GW: POST /api/delivery/drivers/{driverId}/orders/{orderId}/status {status: "PICKED_UP"}
    GW->>DS: Forward
    DS->>DS: Update order delivery status
    DS->>KF: Publish ORDER_STATUS_UPDATED {orderId, status: OUT_FOR_DELIVERY}
    DS-->>GW: 200
    UI-->>U: Show delivery navigation

    Note over U: Driver arrives at customer
    U->>UI: Click "Delivered"
    UI->>GW: POST /api/delivery/drivers/{driverId}/orders/{orderId}/status {status: "DELIVERED"}
    GW->>DS: Forward
    DS->>DS: Update order delivery status
    DS->>DS: Set driver status back to AVAILABLE
    DS->>KF: Publish ORDER_DELIVERED {orderId, driverId}
    DS-->>GW: 200
    UI-->>U: Show delivery complete screen
```

## 5.8 Location Telemetry (Batch Upload)

```mermaid
sequenceDiagram
    participant UI as Driver App
    participant GW as API Gateway
    participant DS as DeliveryTelemetryController
    participant MI as MapsIntegration

    loop Every 10 seconds
        UI->>UI: Collect GPS coordinates
    end
    UI->>GW: POST /api/delivery/telemetry/batch [{lat, lng, timestamp}, ...]
    GW->>DS: Forward (RBAC: DELIVERY)
    DS->>MI: POST /api/fleet/location {driverId, lat, lng}
    MI->>MI: Update driver location in memory/Redis
    DS-->>GW: 200
    GW-->>UI: 200
    Note over MI: Customer tracking SSE reads this location data
```

## 5.9 Delivery Failed

```mermaid
flowchart TD
    A[Driver unable to deliver] --> B[Update status to DELIVERY_FAILED]
    B --> C[Kafka: ORDER_STATUS_UPDATED with status DELIVERY_FAILED]
    C --> D[OrderSagaOrchestrator receives event]
    D --> E[handleDeliveryFailed]
    E --> F[Update order status to DELIVERY_FAILED]
    F --> G[Initiate refund if paid]
    G --> H[Send notification to customer]
```
