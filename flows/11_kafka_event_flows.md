# 11. Kafka Event Flows (Cross-Service Messaging)

## 11.1 Kafka Topics & Producers/Consumers

```mermaid
flowchart LR
    subgraph Topics
        OE[order-events]
        PE[payment-events]
        ND[platform.notifications.dispatch]
        LD[platform.logistics.dispatch]
    end

    subgraph Producers
        CS_P[CustomerService\nOutbox Poller]
        RS_P[RestaurantService\nOutbox Poller]
        DS_P[DeliveryService]
        PS_P[PaymentService\nWebhook Handler]
    end

    subgraph Consumers
        CS_C[CustomerService\nOrderSagaOrchestrator]
        RS_C[RestaurantService\nOrderEventConsumer]
        DS_C[DeliveryService\nOrderEventConsumer]
        NS_C[NotificationService\nConsumer]
        MI_C[MapsIntegration\nDispatchEventConsumer]
    end

    CS_P -->|ORDER_CREATED, ORDER_PAID, DELAY_APPROVED/REJECTED| OE
    RS_P -->|ORDER_ACCEPTED, ORDER_REJECTED, ORDER_READY, DELAY_APPROVAL_REQUESTED, ORDER_CANCELLED_BY_RESTAURANT| OE
    DS_P -->|DRIVER_ASSIGNED, DISPATCH_FAILED, ORDER_DELIVERED, ORDER_STATUS_UPDATED, ORDER_DRIVER_REJECTED| OE
    PS_P -->|Payment success/failure| PE

    OE --> CS_C
    OE --> RS_C
    OE --> DS_C
    PE --> CS_C

    CS_P -->|NOTIFICATION_REQUEST| ND
    ND --> NS_C

    CS_P --> LD
    LD --> MI_C
```

## 11.2 Order Events Topic — Event Flow

```mermaid
sequenceDiagram
    participant CS as CustomerService
    participant KF as Kafka (order-events)
    participant RS as RestaurantService
    participant DS as DeliveryService

    Note over CS,DS: Consumer Groups ensure each service gets every event

    CS->>KF: ORDER_CREATED {orderId, restaurantId, items}
    KF->>RS: [restaurant-service-group] Consume ORDER_CREATED
    KF->>DS: [delivery-service-group] Consume ORDER_CREATED (ignored)
    KF->>CS: [food-delivery-group] Consume ORDER_CREATED (ignored - self)

    CS->>KF: ORDER_PAID {orderId}
    KF->>RS: Consume → Create RestaurantOrder
    KF->>DS: Consume (ignored until ACCEPTED)

    RS->>KF: ORDER_ACCEPTED {orderId, restaurantId}
    KF->>CS: Update order → ACCEPTED
    KF->>DS: Trigger dispatch logic

    DS->>KF: DRIVER_ASSIGNED {orderId, driverId, eta}
    KF->>CS: Update order → DISPATCHED
    KF->>RS: (info only)

    RS->>KF: ORDER_READY {orderId}
    KF->>CS: Update order → READY_FOR_PICKUP
    KF->>DS: (info only)

    DS->>KF: ORDER_DELIVERED {orderId}
    KF->>CS: Update order → DELIVERED (terminal)
    KF->>RS: (info only)
```

## 11.3 Payment Events Topic

```mermaid
flowchart TD
    A[Payment Gateway sends webhook] --> B[PaymentService WebhookController]
    B --> C{Webhook type?}
    C -- Razorpay --> D[processRazorpayWebhook]
    C -- Cashfree --> E[processCashfreeWebhook]
    C -- Vyapar --> F[processVyaparWebhook]
    D --> G[Extract orderId, status]
    E --> G
    F --> G
    G --> H{Payment success or failure?}
    H -- Success --> I[Publish to payment-events: orderId, gatewayOrderId, status]
    H -- Failure --> J[Publish to payment-events: orderId, gatewayOrderId, failureReason]
    I --> K[CustomerService consumes → Order PAID]
    J --> L[CustomerService consumes → Order CANCELLED]
```

## 11.4 Notification Dispatch Topic

```mermaid
flowchart TD
    A[Any service saves NotificationRequestEvent to Outbox] --> B[Outbox Poller publishes]
    B --> C["Kafka: platform.notifications.dispatch"]
    C --> D[NotificationEventConsumer]
    D --> E[NotificationDispatchService.routeAndDispatch]
    E --> F{Channel?}
    F -- SMS --> G[SMS Provider]
    F -- PUSH --> H[Push Provider]
    F -- EMAIL --> I[Email Provider]
```

## 11.5 Logistics Dispatch Topic

```mermaid
flowchart TD
    A[Service publishes dispatch request] --> B["Kafka: platform.logistics.dispatch"]
    B --> C[MapsIntegration DispatchEventConsumer]
    C --> D[Find nearby available drivers]
    D --> E{Candidates found?}
    E -- Yes --> F[Return best candidate to requesting service]
    E -- No --> G[Log failure]
```

## 11.6 Outbox Pattern — Event Publishing

```mermaid
sequenceDiagram
    participant SVC as Service (any)
    participant DB as PostgreSQL
    participant OP as Outbox Poller (Scheduled)
    participant KF as Kafka

    SVC->>DB: Begin Transaction
    SVC->>DB: Save business entity (Order, RestaurantOrder, etc.)
    SVC->>DB: Save OutboxEventEntity {aggregateType, aggregateId, eventType, payload}
    SVC->>DB: Commit Transaction
    Note over SVC,DB: Atomic: both saved or neither

    loop Every N seconds
        OP->>DB: SELECT * FROM outbox_events WHERE published = false
        DB-->>OP: [unpublished events]
        loop Each event
            OP->>KF: Publish to appropriate topic (based on aggregateType)
            KF-->>OP: ACK
            OP->>DB: UPDATE outbox_events SET published = true WHERE id = ?
        end
    end
```

## 11.7 Consumer Group Isolation

```mermaid
flowchart TD
    A["order-events topic\n(6 partitions)"] --> B["food-delivery-group\n(CustomerService)"]
    A --> C["restaurant-service-group\n(RestaurantService)"]
    A --> D["delivery-service-group\n(DeliveryService)"]

    E["payment-events topic"] --> B

    F["platform.notifications.dispatch topic"] --> G["notification-service-group\n(NotificationService)"]

    H["platform.logistics.dispatch topic"] --> I["maps-integration-group\n(MapsIntegration)"]

    Note over B,D: Each group gets ALL messages independently
    Note over B,D: Partitions distributed among group members
```
