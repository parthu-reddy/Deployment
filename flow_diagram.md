# Order Saga Orchestration & Event Flow

This document details the complete end-to-end lifecycle of an order within the Food Delivery system. The architecture relies on an Event-Driven Saga pattern where the `OrderSagaOrchestrator` coordinates transactions across the Payment, Restaurant, and Delivery microservices. 

It explicitly maps how events are triggered (via synchronous REST APIs vs. asynchronous Kafka messages) and details the specific Kafka topics used. It also covers the delayed dispatch edge case using Redis ZSETs.

## Comprehensive Flow Diagram

```mermaid
sequenceDiagram
    autonumber
    
    actor Customer
    participant CA as Customer Application
    participant PGI as Payment Gateway Integration
    participant K_PE as Kafka (payment-events)
    participant K_OE as Kafka (order-events)
    participant RA as Restaurant Application
    participant DEA as Delivery Executive Application
    participant Redis as Redis (ZSET & Geo)
    actor Executive
    
    %% Scenario 1: Order Creation and Payment
    Note over Customer, Executive: SCENARIO: SUCCESSFUL ORDER & PAYMENT
    
    Customer->>CA: POST /api/v1/orders (Place Order)
    CA->>RA: GET /api/v1/restaurants/{id} (Check if Active)
    RA-->>CA: REST Response (Active)
    CA->>RA: GET /api/v1/restaurants/{id}/menu/batch (Fetch Menu & Prep Time)
    RA-->>CA: REST Response (Menu details, max Prep Time)
    
    CA->>PGI: POST /api/v1/payment/intent (Create Payment Intent)
    PGI-->>CA: Payment Intent Response
    CA-->>Customer: Order Created (Status: CREATED)
    
    Customer->>PGI: User completes payment (UPI/Card)
    PGI->>PGI: Webhook triggered: POST /api/payment/webhook
    PGI->>K_PE: Publish PaymentCompletedEvent
    
    CA->>K_PE: Consume PaymentCompletedEvent
    CA->>CA: Update Order Status -> PAID
    CA->>K_OE: Publish OrderPaidEvent (includes estimatedPrepTimeMinutes)
    
    %% Scenario 2: Restaurant Acceptance and Prep
    Note over Customer, Executive: SCENARIO: RESTAURANT ACCEPTANCE
    
    RA->>K_OE: Consume OrderPaidEvent
    RA->>RA: Accept Order & Start Preparation
    RA->>K_OE: Publish OrderAcceptedEvent
    
    %% Scenario 3: Delayed Delivery Dispatch (Redis ZSET)
    Note over Customer, Executive: SCENARIO: DELAYED DELIVERY DISPATCH
    
    DEA->>K_OE: Consume OrderAcceptedEvent
    DEA->>DEA: Calculate dispatchTime = (Now + PrepTime) - 15 mins
    DEA->>Redis: ZADD delayed_dispatch_queue dispatchTime orderId
    
    loop Every 1 Minute (DelayedDispatchPoller)
        DEA->>Redis: ZRANGEBYSCORE delayed_dispatch_queue 0 Now
        Redis-->>DEA: Returns orders ready for dispatch
        DEA->>Redis: ZREM delayed_dispatch_queue (remove processed orders)
        DEA->>Redis: GEORADIUS (Find nearby executives)
        Redis-->>DEA: Returns available executives
        DEA->>DEA: Assign Executive to Order
        DEA->>K_OE: Publish DeliveryExecutiveAssignedEvent
    end
    
    %% Scenario 4: Food Ready & Pickup
    Note over Customer, Executive: SCENARIO: FOOD READY & DELIVERY
    
    RA->>RA: Food Preparation Complete
    RA->>K_OE: Publish FoodReadyEvent
    
    Executive->>DEA: PUT /api/v1/delivery/{orderId}/pickup
    DEA->>K_OE: Publish OrderPickedUpEvent
    
    Executive->>DEA: PUT /api/v1/delivery/{orderId}/deliver
    DEA->>K_OE: Publish OrderDeliveredEvent
    
    %% Scenario 5: Edge Cases
    Note over Customer, Executive: SCENARIO: PAYMENT FAILURE
    PGI->>PGI: Webhook: Payment Failed
    PGI->>K_PE: Publish PaymentFailedEvent
    CA->>K_PE: Consume PaymentFailedEvent
    CA->>CA: Update Order Status -> CANCELLED
    
    Note over Customer, Executive: SCENARIO: RESTAURANT REJECTION
    RA->>K_OE: Consume OrderPaidEvent
    RA->>RA: Reject Order (e.g., Too busy)
    RA->>K_OE: Publish OrderRejectedEvent
    CA->>K_OE: Consume OrderRejectedEvent
    CA->>CA: Update Order Status -> CANCELLED
    CA->>PGI: Initiate Refund (REST/API)
```

## Detailed Explanations

### 1. Synchronous vs Asynchronous Triggers
- **Synchronous (REST APIs)**: Used when immediate responses are required for the user or between systems.
  - Creating an order (`POST /api/v1/orders`)
  - Validating Restaurant & Menu during order creation (`GET /api/v1/restaurants...`)
  - Initiating Payment Intents (`POST /api/v1/payment/intent`)
  - Executive updating status to picked up / delivered (`PUT /api/v1/delivery/...`)
- **Asynchronous (Kafka & Redis)**: Used for eventual consistency, cross-service workflows, and temporal operations.
  - Order state transitions (`order-events`)
  - Payment status updates (`payment-events`)
  - Delayed dispatching based on preparation time (Redis Scheduled Poller)

### 2. Kafka Topics & Events
- `payment-events`:
  - `PaymentCompletedEvent`: Triggered by payment gateway webhook. Consumed by `CustomerApplication` to transition order to `PAID`.
  - `PaymentFailedEvent`: Consumed by `CustomerApplication` to transition order to `CANCELLED`.
- `order-events`:
  - `OrderPaidEvent`: Published by `CustomerApplication`. Consumed by `RestaurantApplication` to begin food preparation.
  - `OrderAcceptedEvent`: Published by `RestaurantApplication`. Consumed by `DeliveryExecutiveApplication` to schedule delivery dispatch.
  - `DeliveryExecutiveAssignedEvent`: Published by `DeliveryExecutiveApplication`.
  - `FoodReadyEvent`: Published by `RestaurantApplication` when cooking is complete.
  - `OrderPickedUpEvent` & `OrderDeliveredEvent`: Published by `DeliveryExecutiveApplication` when the driver updates their app.
  - `OrderRejectedEvent`: Published by `RestaurantApplication` if they cannot fulfill the order.

### 3. The "Just-In-Time" Dispatch Mechanism (Redis ZSET)
Why wait until 15 minutes before the food is ready? 
- If a delivery partner arrives too early, they waste time waiting at the restaurant. 
- If we assign them immediately for a 45-minute preparation, they are blocked from taking other deliveries.

**Implementation**:
1. When `DeliveryExecutiveApplication` consumes `OrderAcceptedEvent`, it does not immediately assign a driver.
2. It calculates `dispatchTime = (CurrentTime + estimatedPrepTimeMinutes) - 15 minutes`.
3. It stores the `orderId` in a Redis Sorted Set (`ZSET`) called `delayed_dispatch_queue` with the `dispatchTime` (Unix timestamp) as the score.
4. A `@Scheduled` background worker (`DelayedDispatchPoller`) runs every 60 seconds, querying Redis using `ZRANGEBYSCORE 0 {currentTime}` to find orders that are due for dispatch.
5. It then uses Redis Geospatial queries to find the nearest available executive and assigns the order.
