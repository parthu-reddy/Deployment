# Order Saga Orchestration Flow

This document details the complete end-to-end lifecycle of an order within the Food Delivery system. The architecture relies on an Event-Driven Saga pattern where the `OrderSagaOrchestrator` coordinates transactions across the Payment, Restaurant, and Delivery microservices. 

The diagram below maps every action to its corresponding system actor, outlining all happy paths and edge cases (such as payment failures, restaurant rejections, and dispatch timeouts).

## Architecture Swimlane Flowchart

```mermaid
flowchart TD
    %% Styling Configuration
    classDef customer fill:#ffcdd2,stroke:#c62828,stroke-width:2px,color:#000;
    classDef orchestrator fill:#bbdefb,stroke:#1565c0,stroke-width:2px,color:#000;
    classDef payment fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px,color:#000;
    classDef restaurant fill:#fff9c4,stroke:#fbc02d,stroke-width:2px,color:#000;
    classDef delivery fill:#e1bee7,stroke:#6a1b9a,stroke-width:2px,color:#000;
    classDef decision fill:#ffe0b2,stroke:#e65100,stroke-width:2px,color:#000,shape:rhombus;
    classDef failure fill:#f8bbd0,stroke:#c2185b,stroke-width:2px,color:#000;
    classDef success fill:#a5d6a7,stroke:#2e7d32,stroke-width:2px,color:#000;
    
    subgraph Customer [Customer Swimlane]
        direction TB
        C1([Initiate Order]):::customer
        C2([Complete Checkout Payment]):::customer
        C3([Push Notification: Driver Assigned]):::customer
        C4([Push Notification: Order Delivered]):::customer
    end

    subgraph Saga [Orchestrator Swimlane]
        direction TB
        S1[Create Order\nStatus: CREATED]:::orchestrator
        S2{Payment Status?}:::decision
        S3[Update Status: PAID]:::orchestrator
        S4{Restaurant Choice?}:::decision
        S5[Update Status: ACCEPTED]:::orchestrator
        S6{Dispatch Status?}:::decision
        S7[Update Status: DISPATCHED]:::orchestrator
        S8[Update Status: READY_FOR_PICKUP]:::orchestrator
        S9{Delivery Outcome?}:::decision
        S10[Update Status: DELIVERED\nProcess Ledger Payouts]:::success
        S11[Initiate Refund Process]:::failure
        S12[Update Status: FAILED / CANCELLED]:::failure
    end

    subgraph Payment [Payment Swimlane]
        direction TB
        P1[Process Payment\nvia Vyapar Gateway]:::payment
        P2[Issue Refund\nvia Vyapar Gateway]:::payment
    end

    subgraph Restaurant [Restaurant Swimlane]
        direction TB
        R1[Review Order\nAccept/Reject]:::restaurant
        R2[Prepare Food]:::restaurant
        R3[Mark Order Ready]:::restaurant
    end

    subgraph Delivery [Delivery Swimlane]
        direction TB
        D1[Ping Nearest Driver]:::delivery
        D2[Driver Accepts/Rejects]:::delivery
        D3[Redispatch Logic\nFind Next Driver]:::delivery
        D4[Pickup Order]:::delivery
        D5[Deliver to Customer]:::delivery
    end

    %% Order Initiation
    C1 -- "HTTP POST /api/v1/customer/orders" --> S1
    S1 -- "HTTP POST /api/v1/payments/intent" --> P1
    C2 -. "Redirect to Gateway" .-> P1
    
    %% Payment Phase
    P1 -- "Webhook -> Kafka (payment-events)" --> S2
    P1 -- "Failure / Timeout" --> S2
    
    S2 -- "Success" --> S3
    S2 -- "Failed" --> S12
    
    %% Restaurant Acceptance Phase
    S3 -- "Kafka (order-events): ORDER_PAID" --> R1
    R1 -- "Kafka (order-events): ORDER_ACCEPTED" --> S4
    R1 -- "Kafka (order-events): ORDER_REJECTED / CANCELLED" --> S4
    
    S4 -- "Accepted" --> S5
    S4 -- "Rejected / Cancelled" --> S11
    
    %% Dispatch Phase
    S5 -- "Kafka (order-events): ORDER_ACCEPTED" --> D1
    D1 -- "HTTP API / Push Notification" --> D2
    D2 -- "Kafka (order-events): DRIVER_ASSIGNED" --> S6
    D2 -- "Kafka (order-events): ORDER_DRIVER_REJECTED" --> D3
    D3 -- "Try Next Nearest Driver" --> D1
    D3 -- "Kafka (order-events): DISPATCH_FAILED" --> S6
    
    S6 -- "Driver Assigned" --> S7
    S6 -- "Dispatch Failed" --> S11
    
    %% Preparation and Delivery Phase
    S7 -. "Kafka (notifications-dispatch)" .-> C3
    S7 --> R2
    R2 --> R3
    R3 -- "Kafka (order-events): ORDER_READY" --> S8
    S8 -- "Push Notification to Driver" --> D4
    D4 --> D5
    
    D5 -- "Kafka (order-events): ORDER_DELIVERED" --> S9
    D5 -- "Kafka (order-events): DELIVERY_FAILED" --> S9
    
    S9 -- "Delivered" --> S10
    S9 -- "Failed" --> S11
    
    S10 -. "Kafka (notifications-dispatch)" .-> C4
    
    %% Refund Flow
    S11 -- "HTTP POST /api/v1/payments/refund" --> P2
    P2 --> S12
```

## Scenario Breakdown & Edge Cases

The following details all scenarios handled by the `OrderSagaOrchestrator` through the Kafka event streams.

### 1. Payment Phase
- **Happy Path:** The external payment gateway successfully captures the funds. `PaymentSucceededEvent` is published to the `payment-events` topic. Orchestrator updates order to `PAID` and emits `ORDER_PAID`.
- **Edge Case (Payment Failure/Timeout):** The order stays in `CREATED` or moves directly to a failed state. The Saga does not proceed to the restaurant.
- **Edge Case (Duplicate Payment Events):** If the payment gateway fires duplicate webhooks, the orchestrator detects the order is already in `PAID` state and ignores the duplicate to maintain idempotency.

### 2. Restaurant Acceptance Phase
- **Happy Path:** Restaurant receives `ORDER_PAID`. The staff reviews and accepts the order. Emits `ORDER_ACCEPTED`. Orchestrator updates status to `ACCEPTED`.
- **Edge Case (Restaurant Rejects):** Staff emits `ORDER_REJECTED` or `ORDER_CANCELLED_BY_RESTAURANT`. Orchestrator catches this, immediately sets order to `DELIVERY_FAILED` and invokes the Refund process via `PaymentGatewayIntegration`.
- **Edge Case (Restaurant Timeout):** If the restaurant doesn't accept in a configured time window (configurable via a scheduler), a timeout event is fired causing automatic rejection and refund.

### 3. Driver Dispatch Phase
- **Happy Path:** Following `ORDER_ACCEPTED`, the `DeliveryExecutiveApplication` queries `MapsIntegration` to find the closest driver and pings them. The driver accepts, emitting `DRIVER_ASSIGNED`. Orchestrator updates to `DISPATCHED` and notifies the customer via `NotificationService`.
- **Edge Case (Driver Rejects Ping):** Driver declines or lets the ping timeout. Emits `ORDER_DRIVER_REJECTED`. The Orchestrator ignores this event, as the `DeliveryExecutiveApplication` internally handles redispatch logic to find the *next* closest driver.
- **Edge Case (Total Dispatch Failure):** The system exhausts all nearby drivers, or no drivers are online. Emits `DISPATCH_FAILED`. Orchestrator catches this, updates status to `DELIVERY_FAILED`, and processes a full refund to the customer.

### 4. Preparation & Delivery Phase
- **Happy Path:** Restaurant staff finishes the food and emits `ORDER_READY`. Orchestrator updates status to `READY_FOR_PICKUP`. Driver picks it up, drives to the customer, and emits `ORDER_DELIVERED`. 
- **Ledger Settlement:** On `ORDER_DELIVERED`, the Orchestrator calculates the financial splits (e.g., 80% to Restaurant, 20% to Platform, flat rate to Driver) and records the double-entry accounting transactions in the `LedgerService`. A final push notification is sent to the customer.
- **Edge Case (Delivery Fails in Transit):** If the driver gets into an accident or cannot find the customer, they emit `DELIVERY_FAILED` (via generic `ORDER_STATUS_UPDATED` event). Orchestrator catches this, logs the failure, and issues a Refund.

### 5. Automated Refund Engine
> [!WARNING]
> The orchestrator implements a unified `processRefund()` mechanism to prevent phantom charges. Any edge case that breaks the Saga chain after payment capture (Restaurant Rejects, Dispatch Fails, Delivery Fails) funnels into this engine.

The engine directly queries the `PaymentGatewayIntegration` REST API using the original `gatewayOrderId`. If the refund REST call fails (e.g., due to network partition), the system logs an error but relies on external reconciliation or retry mechanisms to eventually process the refund, ensuring the double-entry ledger reverse transactions are only recorded upon successful HTTP 2xx confirmation from Vyapar.
