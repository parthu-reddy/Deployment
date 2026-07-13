# 7. End-to-End Order Lifecycle

## 7.1 Complete Order State Machine

```mermaid
stateDiagram-v2
    [*] --> CREATED : Customer places order
    CREATED --> PAID : Payment webhook success
    CREATED --> CANCELLED : Payment failure

    PAID --> ACCEPTED : Restaurant accepts (no delay)
    PAID --> AWAITING_DELAY_APPROVAL : Restaurant requests delay
    PAID --> CANCELLED_BY_RESTAURANT : Restaurant rejects

    AWAITING_DELAY_APPROVAL --> ACCEPTED : Customer approves delay
    AWAITING_DELAY_APPROVAL --> CANCELLED_AND_REFUNDED : Customer rejects delay
    AWAITING_DELAY_APPROVAL --> CANCELLED_AND_REFUNDED : 10-min auto-timeout

    ACCEPTED --> DISPATCHED : Driver assigned
    ACCEPTED --> CANCELLED_BY_RESTAURANT : Restaurant cancels post-accept

    DISPATCHED --> OUT_FOR_DELIVERY : Driver picks up
    DISPATCHED --> DELIVERY_FAILED : Dispatch fails

    READY_FOR_PICKUP --> OUT_FOR_DELIVERY : Driver picks up

    OUT_FOR_DELIVERY --> DELIVERED : Driver delivers

    CANCELLED_BY_RESTAURANT --> CANCELLED_AND_REFUNDED : Refund processed
    DELIVERY_FAILED --> CANCELLED_AND_REFUNDED : Refund processed

    DELIVERED --> [*]
    CANCELLED --> [*]
    CANCELLED_AND_REFUNDED --> [*]
```

## 7.2 Happy Path — End-to-End Sequence

```mermaid
sequenceDiagram
    participant C as Customer
    participant UI as Frontend
    participant GW as API Gateway
    participant CS as CustomerService
    participant PS as PaymentService
    participant PG as Payment Gateway
    participant KF as Kafka
    participant RS as RestaurantService
    participant DS as DeliveryService
    participant MI as MapsIntegration
    participant NS as NotificationService

    Note over C,NS: === Phase 1: Order Creation & Payment ===
    C->>UI: Select items, click "Place Order"
    UI->>GW: POST /api/v1/orders
    GW->>CS: Create order + payment intent
    CS->>PS: Create payment order
    PS-->>CS: gatewayOrderId
    CS-->>UI: {order, paymentIntent}
    C->>PG: Complete payment
    PG->>PS: Webhook (payment.captured)
    PS->>KF: payment-events

    Note over C,NS: === Phase 2: Payment Processing ===
    KF->>CS: Payment success event
    CS->>CS: Order CREATED → PAID
    CS->>KF: ORDER_PAID (outbox)

    Note over C,NS: === Phase 3: Restaurant Accepts ===
    KF->>RS: ORDER_PAID event
    RS->>RS: Create RestaurantOrder (PLACED)
    RS-->>UI: New order appears in Kanban
    RS->>RS: Staff clicks Accept
    RS->>KF: ORDER_ACCEPTED (outbox)

    Note over C,NS: === Phase 4: Driver Dispatch ===
    KF->>CS: ORDER_ACCEPTED
    CS->>CS: Order PAID → ACCEPTED
    KF->>DS: ORDER_ACCEPTED
    DS->>MI: Find nearby driver
    MI-->>DS: candidateDriverId
    DS->>KF: DISPATCH_CANDIDATE_FOUND
    Note over DS: Driver app receives ping
    DS->>DS: Driver accepts
    DS->>KF: DRIVER_ASSIGNED

    Note over C,NS: === Phase 5: Pickup & Delivery ===
    KF->>CS: DRIVER_ASSIGNED
    CS->>CS: Order → DISPATCHED
    CS->>NS: Notification: "Driver on the way"
    DS->>DS: Driver picks up food
    DS->>KF: ORDER_STATUS_UPDATED (OUT_FOR_DELIVERY)
    KF->>CS: Update order status
    DS->>DS: Driver delivers
    DS->>KF: ORDER_DELIVERED
    KF->>CS: ORDER_DELIVERED
    CS->>CS: Order → DELIVERED ✅
```

## 7.3 Unhappy Path — Restaurant Rejects Order

```mermaid
sequenceDiagram
    participant CS as CustomerService
    participant KF as Kafka
    participant RS as RestaurantService
    participant PS as PaymentService

    Note over CS: Order is PAID
    RS->>RS: Staff clicks "Reject"
    RS->>KF: ORDER_REJECTED
    KF->>CS: ORDER_REJECTED event
    CS->>CS: Order PAID → CANCELLED_BY_RESTAURANT
    CS->>CS: processRefund(order)
    CS->>PS: POST /api/v1/payments/refund
    PS-->>CS: Refund success
    CS->>CS: PaymentIntent → REFUNDED
    CS->>CS: Ledger: Platform → Customer
```

## 7.4 Unhappy Path — Delay Rejected by Customer

```mermaid
sequenceDiagram
    participant C as Customer
    participant CS as CustomerService
    participant KF as Kafka
    participant RS as RestaurantService
    participant PS as PaymentService

    RS->>KF: ORDER_DELAY_APPROVAL_REQUESTED
    KF->>CS: Update order → AWAITING_DELAY_APPROVAL
    CS->>C: Notification: "Restaurant needs extra time"
    C->>CS: POST /delay-approval {approved: false}
    CS->>KF: ORDER_DELAY_REJECTED
    KF->>CS: handleDelayRejected
    CS->>CS: Order → CANCELLED_AND_REFUNDED
    CS->>PS: Process refund
    KF->>RS: ORDER_DELAY_REJECTED
    RS->>RS: Cancel RestaurantOrder
```

## 7.5 Unhappy Path — Dispatch Fails (No Drivers Available)

```mermaid
sequenceDiagram
    participant CS as CustomerService
    participant KF as Kafka
    participant DS as DeliveryService
    participant MI as MapsIntegration

    DS->>MI: POST /api/logistics/dispatch
    MI-->>DS: 404 No candidates found
    DS->>KF: DISPATCH_FAILED {orderId}
    KF->>CS: DISPATCH_FAILED
    CS->>CS: handleDispatchFailed
    CS->>CS: Order → DELIVERY_FAILED
    CS->>CS: processRefund(order)
```

## 7.6 Unhappy Path — All Drivers Reject/Timeout

```mermaid
flowchart TD
    A[Order ACCEPTED, dispatch initiated] --> B[Find nearest driver]
    B --> C{Driver found?}
    C -- Yes --> D[Ping driver with 30s timeout]
    D --> E{Driver accepts?}
    E -- Yes --> F[DRIVER_ASSIGNED → proceed with delivery]
    E -- No/Timeout --> G[Mark driver as rejected]
    G --> H{More candidates?}
    H -- Yes --> B
    H -- No --> I[DISPATCH_FAILED]
    I --> J[Order → DELIVERY_FAILED + Refund]
    C -- No --> I
```

## 7.7 Unhappy Path — Delivery Failed

```mermaid
sequenceDiagram
    participant DS as DeliveryService
    participant KF as Kafka
    participant CS as CustomerService
    participant PS as PaymentService

    Note over DS: Driver cannot complete delivery
    DS->>KF: ORDER_STATUS_UPDATED {status: DELIVERY_FAILED}
    KF->>CS: DELIVERY_FAILED event
    CS->>CS: Order → DELIVERY_FAILED
    CS->>PS: Process refund
    CS->>CS: Notify customer
```
