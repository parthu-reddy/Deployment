# End-to-End Flow Diagrams and Scenarios

This document outlines the end-to-end data communication, state transitions, and UI updates for all possible scenarios in the Food Delivery platform. It incorporates the decoupled `OrderStatus` and `DeliveryStatus` architecture.

## 1. Happy Path: End-to-End Delivery

```mermaid
sequenceDiagram
    participant CUI as Customer UI
    participant RUI as Restaurant UI
    participant DUI as Driver UI
    participant CA as Customer App (Saga)
    participant RA as Restaurant App
    participant DA as Delivery App
    participant K as Kafka

    %% Order Creation & Payment
    CUI->>CA: POST /order (Create)
    CA->>CUI: Order Created (PENDING_PAYMENT)
    CUI->>CA: Process Payment
    CA->>K: ORDER_PAID
    
    %% Restaurant Acceptance
    K->>RA: Consumer creates order in RA DB
    RUI->>RA: Fetch Orders (sees new order)
    RUI->>RA: Accept Order
    RA->>K: ORDER_ACCEPTED
    K->>CA: Consumer updates CA DB (OrderStatus=ACCEPTED)
    CUI->>CA: Fetch Status -> UI shows "Accepted"

    %% Dispatch
    CA->>K: DISPATCH_REQUEST
    K->>DA: Starts driver assignment search
    DA->>DUI: Broadcast to nearby drivers
    DUI->>DA: Driver accepts
    DA->>K: DRIVER_ASSIGNED
    K->>CA: DeliveryStatus=ASSIGNED
    K->>RA: Updates RA DB (driver info)

    %% Preparation
    RUI->>RA: Mark as PREPARING
    RA->>K: ORDER_STATUS_UPDATED (PREPARING)
    K->>CA: OrderStatus=PREPARING
    CUI->>CA: Fetch Status -> UI shows "Preparing"

    %% Pickup
    RUI->>RA: Mark as READY_FOR_PICKUP
    RA->>K: ORDER_STATUS_UPDATED (READY_FOR_PICKUP)
    K->>CA: OrderStatus=READY_FOR_PICKUP
    
    DUI->>DA: Mark AT_RESTAURANT
    DA->>K: DRIVER_AT_RESTAURANT
    K->>CA: DeliveryStatus=AT_RESTAURANT
    K->>RA: Updates DeliveryStatus

    %% Handover
    DUI->>DA: Driver verifies Pickup OTP
    DA->>K: ORDER_STATUS_UPDATED (HANDED_OVER)
    K->>CA: OrderStatus=HANDED_OVER, DeliveryStatus=OUT_FOR_DELIVERY
    K->>RA: OrderStatus=HANDED_OVER

    %% Delivery
    DUI->>DA: Driver verifies Delivery OTP
    DA->>K: ORDER_DELIVERED
    K->>CA: OrderStatus=DELIVERED, DeliveryStatus=DELIVERED
    CUI->>CA: Fetch Status -> UI shows "Delivered"
```

## 2. Dispatch Failure & Admin Intervention

When the delivery service cannot find a driver, the food might still be cooking. We decouple the delivery state so the food isn't wasted, and admin intervention is required.

```mermaid
sequenceDiagram
    participant CUI as Customer UI
    participant RUI as Restaurant UI
    participant AUI as Admin UI
    participant CA as Customer App (Saga)
    participant RA as Restaurant App
    participant DA as Delivery App
    participant K as Kafka

    Note over CA,DA: Order is ACCEPTED or PREPARING
    
    %% Dispatch Fails
    DA->>K: PRIORITY_DISPATCH_FAILED
    K->>CA: DeliveryStatus=FAILED (OrderStatus remains unchanged)
    
    %% Admin sees the issue
    AUI->>CA: Fetch Orders (polls for interventions)
    Note over AUI: Admin UI sees DeliveryStatus = FAILED.<br>Shows "Driver Assignment Failed" alert.
    
    alt Admin Manually Assigns Driver
        AUI->>CA: POST /admin/order/{id}/assign-driver
        CA->>K: DRIVER_ASSIGNED
        K->>CA: DeliveryStatus=ASSIGNED
        K->>RA: Updates driver info
        K->>DA: Delivery App tracks new driver
        Note over AUI: Admin UI resolves alert
    else Admin Cancels Order (No drivers available)
        AUI->>CA: POST /admin/order/{id}/cancel
        CA->>K: ORDER_CANCELLED_BY_ADMIN
        
        K->>CA: OrderStatus=CANCELLED, RequiresRefund=true
        CA->>CA: Issue Refund
        CUI->>CA: UI shows "Cancelled by Admin, Refund Issued"
        
        K->>RA: OrderStatus=CANCELLED
        RUI->>RA: UI removes order from active prep queue
        Note over AUI: Admin UI resolves alert
    end
```

## 3. Abandoned Delivery & Admin Intervention

If a driver picks up the order but vanishes or fails to deliver within a set time frame (e.g., 2 hours).

```mermaid
sequenceDiagram
    participant CUI as Customer UI
    participant AUI as Admin UI
    participant CA as Customer App (Saga)
    participant K as Kafka

    Note over CA: Order is HANDED_OVER, DeliveryStatus=OUT_FOR_DELIVERY
    
    %% Sweeper Job
    loop Every 5 Minutes
        CA->>CA: AbandonedDeliverySweeper checks DB
        CA->>CA: Finds order HANDED_OVER older than 2 hours
        CA->>K: Emits DELIVERY_FAILED event
        K->>CA: OrderSaga consumes DELIVERY_FAILED
        CA->>CA: handleDeliveryFailed
        CA->>CA: Updates DeliveryStatus=FAILED, RequiresRefund=true
    end
    
    %% Admin Intervention
    AUI->>CA: Fetch Orders
    Note over AUI: Admin UI sees OrderStatus=HANDED_OVER<br>and DeliveryStatus=FAILED. Shows alert.
    
    %% Admin Cancels
    AUI->>CA: Admin determines food lost. POST /admin/order/{id}/cancel
    CA->>K: ORDER_CANCELLED_BY_ADMIN
    K->>CA: OrderSaga consumes ORDER_CANCELLED_BY_ADMIN
    CA->>CA: handleOrderCancelledByAdmin
    K->>CA: OrderStatus=CANCELLED, RequiresRefund=true
```

## 4. Delay Requested by Restaurant

```mermaid
sequenceDiagram
    participant CUI as Customer UI
    participant RUI as Restaurant UI
    participant CA as Customer App
    participant RA as Restaurant App
    participant K as Kafka

    %% Request Delay
    RUI->>RA: Request 15 min delay
    RA->>K: ORDER_DELAY_APPROVAL_REQUESTED
    
    K->>CA: Status=AWAITING_DELAY_APPROVAL
    K->>RA: Status=AWAITING_DELAY_APPROVAL
    
    %% Customer Decides
    CUI->>CA: UI shows Delay Request Modal
    alt Customer Approves
        CUI->>CA: Approve Delay
        CA->>K: ORDER_DELAY_APPROVED
        K->>CA: Restores previous status (e.g., ACCEPTED)
        K->>RA: Restores previous status
    else Customer Rejects
        CUI->>CA: Reject Delay (Cancel Order)
        CA->>K: ORDER_DELAY_REJECTED
        K->>CA: Status=CANCELLED, Refund=true
        K->>RA: Status=CANCELLED
        RUI->>RA: UI removes order
    end
```

## 5. Restaurant Cancellation

```mermaid
sequenceDiagram
    participant CUI as Customer UI
    participant RUI as Restaurant UI
    participant CA as Customer App
    participant RA as Restaurant App
    participant K as Kafka

    Note over RA: Restaurant runs out of ingredients
    RUI->>RA: Reject/Cancel Order
    RA->>K: ORDER_CANCELLED_BY_RESTAURANT
    
    K->>CA: OrderStatus=CANCELLED_BY_RESTAURANT, Refund=true
    K->>RA: OrderStatus=CANCELLED
    
    CUI->>CA: Fetch Status
    Note over CUI: UI shows "Cancelled by Restaurant" & Refund message
```

## 6. Customer Cancellation (Before vs After Acceptance)

```mermaid
sequenceDiagram
    participant CUI as Customer UI
    participant CA as Customer App
    participant RA as Restaurant App
    participant K as Kafka

    %% Before Acceptance
    CUI->>CA: Cancel Order (Status = PENDING_ACCEPTANCE)
    CA->>K: ORDER_CANCELLED_BY_CUSTOMER
    K->>CA: Status=CANCELLED, Refund=true
    K->>RA: Status=CANCELLED (Restaurant UI removes order)
    
    %% After Acceptance
    CUI->>CA: Cancel Order (Status = ACCEPTED/PREPARING)
    CA-->>CUI: Returns Error (Cannot cancel after restaurant accepts)
    Note over CUI: UI shows "Cannot cancel, food is being prepared"
```

## 7. Payment Failure

```mermaid
sequenceDiagram
    participant CUI as Customer UI
    participant PS as Payment Service (External)
    participant CA as Customer App (Saga)
    participant K as Kafka

    CUI->>CA: POST /order (Create)
    CA->>CUI: Order Created (PENDING_PAYMENT)
    
    CUI->>PS: Process Payment (Card declines)
    PS->>K: PAYMENT_FAILED
    
    K->>CA: Customer App consumes event
    CA->>CA: handlePaymentFailure
    CA->>CA: OrderStatus=CANCELLED, PaymentStatus=FAILED
    CA->>K: ORDER_CANCELLED
    
    CUI->>CA: Fetch Status
    Note over CUI: UI shows "Payment Failed. Order Cancelled."
```

## 8. Driver Rejection & Re-Dispatch

If the first matched driver rejects the order or times out, the system must loop and attempt to find another driver before finally resorting to `PRIORITY_DISPATCH_FAILED`.

```mermaid
sequenceDiagram
    participant DUI as Driver UI
    participant DA as Delivery App
    participant K as Kafka
    participant CA as Customer App

    CA->>K: DISPATCH_REQUEST
    K->>DA: Starts driver assignment search
    DA->>DUI: Broadcast to Driver A
    
    %% Driver Rejects
    DUI->>DA: Driver A rejects order (or times out)
    DA->>K: ORDER_DRIVER_REJECTED
    
    %% Saga removes driver and triggers sync
    K->>CA: OrderSaga consumes ORDER_DRIVER_REJECTED
    CA->>CA: order.setDeliveryExecutiveId(null)
    CA->>K: ORDER_STATUS_SYNC
    
    %% Delivery App Retries
    K->>DA: Delivery App sees unassigned order
    DA->>DUI: Broadcast to Driver B
    
    alt Driver B Accepts
        DUI->>DA: Driver B accepts
        DA->>K: DRIVER_ASSIGNED
        K->>CA: DeliveryStatus=ASSIGNED
    else Driver B Rejects & Max Retries Reached
        DUI->>DA: Driver B rejects
        DA->>DA: Max retries exceeded
        DA->>K: PRIORITY_DISPATCH_FAILED
        Note over K,CA: See Scenario 2 for Admin Intervention
    end
```

## 9. Delivery Failed (Post-Pickup)

This scenario occurs when the driver has already picked up the food from the restaurant but is unable to deliver it to the customer (e.g., driver vehicle breakdown, customer unreachable at location, address invalid).

```mermaid
sequenceDiagram
    participant DUI as Driver UI
    participant DA as Delivery App
    participant K as Kafka
    participant CA as Customer App (Saga)
    participant CUI as Customer UI

    Note over DA,CA: OrderStatus = HANDED_OVER, DeliveryStatus = PICKED_UP
    DUI->>DA: Driver reports delivery failed (e.g. customer unreachable)
    DA->>K: DELIVERY_FAILED
    
    K->>CA: OrderSaga consumes DELIVERY_FAILED
    CA->>CA: handleDeliveryFailed
    CA->>CA: DeliveryStatus = FAILED, RequiresRefund = true
    CA->>CA: processRefund(Order)
    
    CA->>K: PAYMENT_REFUND_REQUESTED
    CA->>CUI: Push Notification (Delivery Failed, refund initiated)
    
    Note over CUI: UI shows "Delivery Failed. We are processing your refund."
```

## 10. Driver Aborts Delivery (Emergency)

If a driver has already accepted the order but experiences an emergency (e.g., vehicle breakdown) before picking up the food, they can abort the delivery. This immediately unassigns them, frees them up in the pool (or puts them offline), and re-triggers the dispatch loop.

```mermaid
sequenceDiagram
    participant DUI as Driver UI
    participant DA as Delivery App
    participant K as Kafka
    participant CA as Customer App (Saga)

    Note over DUI, CA: Driver has already ACCEPTED the order
    
    %% Driver Aborts
    DUI->>DA: POST /api/v1/delivery/drivers/{driverId}/orders/{orderId}/abort
    DA->>DA: Free driver (Status=ONLINE)<br>Delete Redis Locks
    DA->>K: ORDER_DRIVER_REJECTED

    par Customer App Handling
        K->>CA: OrderSaga consumes ORDER_DRIVER_REJECTED
        CA->>CA: order.deliveryExecutiveId = null
    and Delivery App Redispatch
        K->>DA: OrderDriverRejectedStrategy consumes event
        DA->>DA: Add order to delayed_dispatch_queue (10s delay)
        loop Background Poller
            DA->>DA: LogisticsDispatchPoller reads queue
            DA->>DA: Initiate Assignment (Ping next driver)
        end
    end
```
