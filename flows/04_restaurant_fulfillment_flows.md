# 4. Restaurant Fulfillment Flows

## 4.1 Order Arrives at Restaurant (Kafka Consumer)

```mermaid
sequenceDiagram
    participant KF as Kafka (order-events)
    participant RC as RestaurantApp OrderEventConsumer
    participant RS as RestaurantService
    participant DB as Restaurant DB

    KF->>RC: ORDER_CREATED event {orderId, restaurantId, items, deliveryLat, deliveryLng}
    RC->>RC: Parse event, extract eventType
    RC->>RC: Look up RestaurantEventStrategy for eventType
    alt Strategy found
        RC->>RS: strategy.process(event)
        RS->>DB: Create RestaurantOrder (orderId, restaurantId, status: PLACED)
        RS->>RS: Calculate prep_time from menu items
        RS-->>RC: Done
    else No strategy
        RC->>RC: Log "No strategy mapped, ignoring"
    end
```

## 4.2 Accept Order (No Delay)

```mermaid
sequenceDiagram
    participant U as Restaurant Staff
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService
    participant KF as Kafka

    U->>UI: Click "Accept" on pending order card
    UI->>GW: POST /api/v1/restaurants/{restaurantId}/fulfillment/orders/{orderId}/accept
    GW->>RS: Forward (RBAC: RESTAURANT + ownership)
    RS->>RS: Find RestaurantOrder by orderId
    RS->>RS: Update status to ACCEPTED
    RS->>RS: Save ORDER_ACCEPTED event to Outbox
    RS-->>GW: 200 "Order accept processed"
    GW-->>UI: 200
    Note over RS: Outbox poller publishes to Kafka
    KF->>KF: ORDER_ACCEPTED event on order-events topic
    UI-->>U: Move order card to "Accepted" column
```

## 4.3 Accept Order With Delay (Delay Approval Request)

```mermaid
sequenceDiagram
    participant U as Restaurant Staff
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService
    participant KF as Kafka
    participant CS as CustomerService (Saga)

    U->>UI: Click "Accept with Delay" on pending order
    U->>UI: Enter additional prep time (e.g., 20 min) and reason
    UI->>GW: POST /api/v1/restaurants/{restaurantId}/fulfillment/orders/{orderId}/accept {additionalPrepTime: 20, delayReason: "High demand"}
    GW->>RS: Forward
    RS->>RS: additionalPrepTime > 0 → needs customer approval
    RS->>RS: Save ORDER_DELAY_APPROVAL_REQUESTED event to Outbox
    RS->>RS: Update order status
    RS-->>GW: 200
    GW-->>UI: 200
    Note over RS: Outbox publishes to Kafka
    KF->>CS: ORDER_DELAY_APPROVAL_REQUESTED
    CS->>CS: Update Order status → AWAITING_DELAY_APPROVAL
    CS->>CS: Send notification to customer
    UI-->>U: Show "Waiting for customer approval"
```

## 4.4 Reject Order

```mermaid
sequenceDiagram
    participant U as Restaurant Staff
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService
    participant KF as Kafka
    participant CS as CustomerService (Saga)

    U->>UI: Click "Reject" on pending order
    UI->>GW: POST /api/v1/restaurants/{restaurantId}/fulfillment/orders/{orderId}/reject
    GW->>RS: Forward
    RS->>RS: Update RestaurantOrder status to REJECTED
    RS->>RS: Save ORDER_REJECTED event to Outbox
    RS-->>GW: 200 "Order rejected"
    GW-->>UI: 200
    Note over RS: Outbox publishes to Kafka
    KF->>CS: ORDER_REJECTED
    CS->>CS: Update Order status → CANCELLED_BY_RESTAURANT
    CS->>CS: Trigger refund flow (if paid)
    UI-->>U: Remove order from active view
```

## 4.5 Mark Order Ready for Pickup

```mermaid
sequenceDiagram
    participant U as Restaurant Staff
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService
    participant KF as Kafka
    participant CS as CustomerService (Saga)

    U->>UI: Click "Ready" on preparing order
    UI->>GW: POST /api/v1/restaurants/{restaurantId}/fulfillment/orders/{orderId}/ready
    GW->>RS: Forward
    RS->>RS: Update RestaurantOrder status to READY
    RS->>RS: Save ORDER_READY event to Outbox
    RS-->>GW: 200 "Order ready for pickup"
    GW-->>UI: 200
    Note over RS: Outbox publishes to Kafka
    KF->>CS: ORDER_READY
    CS->>CS: Update Order status → READY_FOR_PICKUP
    CS->>CS: Send notification to customer
    UI-->>U: Move to "Ready for Pickup" column
```

## 4.6 Cancel Order After Acceptance

```mermaid
sequenceDiagram
    participant U as Restaurant Staff
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant RS as RestaurantService
    participant KF as Kafka
    participant CS as CustomerService (Saga)

    U->>UI: Click "Cancel" on accepted/preparing order
    UI->>GW: POST /api/v1/restaurants/{restaurantId}/fulfillment/orders/{orderId}/cancel
    GW->>RS: Forward
    RS->>RS: Update RestaurantOrder status to CANCELLED
    RS->>RS: Save ORDER_CANCELLED_BY_RESTAURANT event to Outbox
    RS-->>GW: 200 "Order cancelled"
    GW-->>UI: 200
    Note over RS: Outbox publishes to Kafka
    KF->>CS: ORDER_CANCELLED_BY_RESTAURANT
    CS->>CS: Update Order status → CANCELLED_BY_RESTAURANT
    CS->>CS: Trigger refund flow
    UI-->>U: Remove from Kanban board
```

## 4.7 Toggle Store Online/Offline

```mermaid
flowchart TD
    A[Restaurant staff clicks toggle] --> B{Currently accepting orders?}
    B -- Yes --> C[Set store to OFFLINE]
    C --> D[UI shows red status indicator]
    D --> E[New orders will not be routed to this outlet]
    B -- No --> F[Set store to ONLINE]
    F --> G[UI shows green pulsing indicator]
    G --> H[Store is now visible for customer orders]
    Note over A: This is currently UI-only state, not persisted to backend
```

## 4.8 Kitchen Kanban Board Flow

```mermaid
flowchart LR
    A["Pending\n(placed/on_hold)"] -->|Accept| B["Accepted\n(accepted)"]
    A -->|Accept with Delay| C["Awaiting Approval\n(waiting)"]
    A -->|Reject| D["Rejected\n(removed)"]
    C -->|Customer Approves| B
    C -->|Customer Rejects| D
    C -->|10min Timeout| D
    B -->|Preparing| E["Preparing\n(preparing)"]
    E -->|Ready| F["Ready for Pickup\n(ready)"]
    E -->|Cancel| D
    F -->|Driver Picks Up| G["Out for Delivery"]
    G -->|Delivered| H["Completed"]
```
