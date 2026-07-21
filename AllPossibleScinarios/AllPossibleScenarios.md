# Food Delivery System - All Possible Scenarios & Edge Cases

This document outlines all possible scenarios, state transitions, and edge cases for the Food Delivery microservices architecture, specifically focusing on the interaction between Customer, Restaurant, Delivery, and Payment services.

## 1. Happy Paths (Normal Execution)

### 1.1 Pre-Checkout Validation (Synchronous Checks)
Before an order is even persisted, the `CustomerOrderService` performs concurrent checks:
1. **Restaurant Check**: Fails immediately if the restaurant is inactive or closed.
2. **Delivery Radius Check**: Fails if the distance (Haversine formula) between the restaurant and customer exceeds the maximum allowed radius.
3. **Fleet Availability Check**: Fails immediately (`DeliveryPartnerUnavailableException`) if Maps Integration reports zero available drivers nearby, preventing unfulfillable orders.

### 1.2 Standard End-to-End Success
1. Customer places order (`CREATED`).
2. Payment succeeds (`PAYMENT_SUCCESS` -> `PAID`).
3. Restaurant auto-accepts or manually accepts (`ACCEPTED`).
4. Restaurant starts cooking (`PREPARING`).
5. Restaurant finishes cooking (`READY_FOR_PICKUP`).
6. Dispatcher finds a driver (`DRIVER_ASSIGNED`).
7. Driver picks up the food (`DISPATCHED` / `OUT_FOR_DELIVERY`).
8. Driver delivers the food to the customer (`DELIVERED`).

### 1.2 Success with Restaurant Delay (Approved)
1. Customer places order -> Payment succeeds.
2. Restaurant needs more time and requests a delay (`ON_HOLD` / `AWAITING_DELAY_APPROVAL`).
3. Customer receives notification and **approves** the delay.
4. Order resumes normal flow (`ACCEPTED` -> `PREPARING` -> `READY` -> `DELIVERED`).

---

## 2. Payment Failure Scenarios

### 2.1 Immediate Payment Failure
1. Customer places order (`CREATED`).
2. Payment Gateway returns a failure (`PAYMENT_FAILED`).
3. Saga terminates. Order is marked as `PAYMENT_FAILED`. No other services are involved.

### 2.2 Payment Intent Generation Failure (Immediate Compensation)
1. Customer places order (`CREATED`), and it is persisted to the DB.
2. System calls `PaymentGatewayOrchestrator` to generate a UPI intent, but it fails (e.g., Gateway is down).
3. `CustomerOrderService` catches the exception and immediately persists an `ORDER_CANCELLED` outbox event to kill the Saga before it propagates.
4. Order is marked `CANCELLED`.

### 2.3 Payment Timeout (Stale Order Sweeper)
1. Customer places order (`CREATED`) but does not complete the payment.
2. The `StaleOrderSweeper` cron job detects the order has been in `CREATED` state for over 15 minutes.
3. System automatically cancels the order (`CANCELLED`).
4. Event `ORDER_CANCELLED` is published.

### 2.4 Webhook Signature Validation Failure
1. Payment Gateway sends a webhook for a successful or failed payment.
2. `PaymentGatewayIntegration` service validates the cryptographic signature using the gateway's secret.
3. If the signature is invalid (potential malicious attack), the service drops the request with `401 Unauthorized`.
4. The system state remains unaffected.

### 2.5 Duplicate Webhook (Replay / Retry)
1. Payment Gateway sends a webhook that was already processed (e.g. gateway retries due to network blip).
2. `WebhookProcessingService` uses an idempotency key (Event ID) to check `isEventProcessed(eventId)`.
3. If already processed, it immediately returns `200 OK` to satisfy the gateway without re-triggering Saga events.

### 2.6 Refund Webhook Misinterpreted as Payment Success (Critical Edge Case)
1. A customer or admin initiates a partial or full refund on the payment gateway dashboard.
2. The Gateway fires a webhook; `PaymentGatewayIntegration` processes it and marks its local intent as `PARTIALLY_REFUNDED` or `REFUNDED`.
3. It emits a `PAYMENT_REFUNDED` event to the outbox/Kafka `payment-events` topic.
4. **Bug**: `OrderSagaOrchestrator.handlePaymentEvents` in `CustomerApplication` consumes the event but *fails to check* the `eventType`. Because the payload contains `orderId` and `gatewayOrderId` but lacks a `failureReason`, the orchestrator mistakenly assumes it is a late `PAYMENT_SUCCESS` event.
5. `TerminalState` triggers `handlePaymentSuccess`, which erroneously overwrites the customer DB's intent status back to `SUCCESS` and issues a duplicate ledger refund transaction!

### 2.7 Saga Event Loss due to Exhausted Retries (Resilience Edge Case)
1. `OrderSagaOrchestrator` consumes a valid event from Kafka (e.g. `ORDER_ACCEPTED`).
2. Concurrent database updates cause an `ObjectOptimisticLockingFailureException`.
3. The orchestrator catches this and retries up to `MAX_OPTIMISTIC_LOCK_RETRIES` (default 3 times).
4. If the database remains locked or highly contended and all 3 retries are exhausted, the exception bubbles up.
5. Spring Kafka's default ErrorHandler logs the error but **ACKs the message**, committing the offset. 
6. The Saga event is permanently lost and the Order hangs in a zombie state indefinitely (e.g. stuck in `PAID` forever).

### 2.8 Late Payment Success on Cancelled Order
1. Order is placed but payment gets delayed.
2. The `StaleOrderSweeper` or Customer cancels the order due to timeout. The order moves to `CANCELLED`.
3. The payment gateway successfully processes the payment late and fires a `PAYMENT_SUCCESS` webhook.
4. The system delegates handling to `TerminalState` since the order is `CANCELLED`.
5. `TerminalState` issues an automatic immediate refund to correct the discrepancy, UNLESS the cancellation was intentionally initiated by the customer (in which case the refund is suppressed as a cancellation penalty).

---

## 3. Restaurant Rejection & Cancellation Scenarios

### 3.1 Upfront Rejection
1. Payment succeeds (`PAID`).
2. Restaurant sees the order and manually rejects it (e.g., out of stock).
3. Status changes to `REJECTED` / `CANCELLED_BY_RESTAURANT`.
4. Saga triggers a full refund (`CANCELLED_AND_REFUNDED`).

### 3.2 Mid-Preparation Cancellation
1. Restaurant accepts and starts preparing (`PREPARING`).
2. An unexpected issue occurs (e.g., equipment failure) and the Restaurant cancels.
3. Status changes to `CANCELLED_BY_RESTAURANT`.
4. Saga triggers a full refund. 
5. Delivery Service (if already searching for a driver) is notified to abort dispatch.

### 3.3 Restaurant Timeout (Auto-Cancel)
1. Payment succeeds (`PAID`).
2. Restaurant fails to accept or reject within the SLA (e.g., 5-10 minutes).
3. System automatically cancels the order (`CANCELLED`).
4. Saga triggers a full refund.

---

## 4. Delay Approval Scenarios (Customer Side)

### 4.1 Delay Rejected by Customer
1. Restaurant requests extra prep time (`AWAITING_DELAY_APPROVAL`).
2. Customer is unhappy with the delay and **rejects** it.
3. Order is immediately `CANCELLED_BY_RESTAURANT` (since the delay was restaurant-initiated and unacceptable).
4. Saga triggers a full refund (`CANCELLED_AND_REFUNDED`).

### 4.2 Delay Timeout (Customer Unresponsive)
1. Restaurant requests extra prep time.
2. Customer does not respond within the time limit (e.g., 10 minutes).
3. System assumes rejection/timeout and automatically changes to `CANCELLED_BY_RESTAURANT`.
4. Saga triggers a full refund (`CANCELLED_AND_REFUNDED`).

### 4.3 Customer Initiated Cancellation (Pre-Acceptance)
1. Customer places an order and pays (`CREATED` or `PAID` state).
2. Customer changes their mind and cancels the order *before* the restaurant accepts it.
3. Order is immediately `CANCELLED`.
4. Saga triggers a full refund.

---

## 5. Dispatch & Delivery Scenarios

### 5.1 Maps Dispatch Candidate Search (Micro-Interaction)
1. Delivery Service starts searching for a driver.
2. Maps Integration identifies a candidate and emits `DISPATCH_CANDIDATE_FOUND`.
3. The specific driver receives a ping.
4. If the driver rejects or ignores the ping, Delivery Service emits `ORDER_DRIVER_REJECTED`.
5. Delivery Service re-enters the dispatch loop to find another candidate.

### 5.2 Complete Dispatch Failure (No Drivers Available)
1. Restaurant accepts or starts preparing.
2. Delivery Service repeatedly fails to find a driver in the vicinity (Maps Integration finds zero candidates).
3. Delivery Service emits `DISPATCH_FAILED`.
4. Customer Service marks order as `DELIVERY_FAILED`.
5. Orchestrator forces Restaurant Service to `DELIVERY_FAILED` via `ORDER_STATUS_SYNC`.
6. Customer is fully refunded. Food is discarded or consumed by staff.

### 5.3 Driver Re-assignment (Driver Aborts)
1. Driver is assigned (`DRIVER_ASSIGNED`).
2. Driver cancels the assignment (flat tire, emergency) before picking up.
3. Delivery Service puts the order back into the queue.
4. New driver is found and assigned.
5. Flow resumes normally. (No Saga interruption unless dispatch ultimately fails).

### 5.4 Delivery Failure (Customer Unreachable)
1. Driver picks up food (`OUT_FOR_DELIVERY`).
2. Driver reaches location but cannot contact the customer.
3. Driver marks delivery as failed.
4. Status changes to `DELIVERY_FAILED`.
5. Typically, **no refund** or a **partial refund** is issued depending on business policy.

### 5.5 Driver Abandons Delivery (Timeout)
1. Driver picks up food (`OUT_FOR_DELIVERY`) or is en route (`DISPATCHED`).
2. No updates are received from the driver for over 2 hours.
3. The `AbandonedDeliverySweeper` cron job detects the stale order.
4. Order is marked as `DELIVERY_FAILED`.
5. Event `ORDER_DELIVERY_FAILED` is published. Order syncs to Restaurant and refund/support flow is initiated.

### 5.6 Driver Enters Wrong Pickup OTP
1. Driver arrives at the restaurant and requests the food.
2. Driver enters an incorrect OTP into the application to mark the order as `DISPATCHED`.
3. The system validates the OTP against the `pickupOtp` generated during Saga instantiation.
4. Validation fails, throwing `IllegalStateTransitionException`. The request is rejected (HTTP 400).
5. Driver must enter the correct OTP to proceed.

### 5.7 Driver Enters Wrong Delivery OTP
1. Driver arrives at the customer's location.
2. Driver enters an incorrect OTP into the application to mark the order as `DELIVERED`.
3. The system validates the OTP against the `deliveryOtp` (or `otp`).
4. Validation fails, throwing `IllegalStateTransitionException`. The request is rejected (HTTP 400).
5. Driver must enter the correct OTP to finalize the delivery.

### 5.8 Driver Accepts Order Early (While Preparing)
1. Delivery Service starts searching for a driver while the restaurant is still in `ACCEPTED` or `PREPARING` state.
2. A driver receives the dispatch ping and accepts it.
3. The order is assigned to the driver (`DRIVER_ASSIGNED`) and their status becomes `BUSY`.
4. The system correctly identifies the order as active for this driver (rather than history) because the query includes `ACCEPTED` and `PREPARING` in the active orders filter.
5. The driver travels to the restaurant and waits until the state reaches `READY_FOR_PICKUP`.

---

## 6. Edge Cases & Race Conditions (Saga Sync)

### 6.1 Cancellation Race Condition during Dispatch (Delivery Lock)
*Scenario:* The Restaurant cancels the order midway (`ORDER_CANCELLED_BY_RESTAURANT`), but a driver is simultaneously accepting the dispatch ping.
*Resolution:*
- `DeliveryExecutiveApplication` receives the terminal cancellation event.
- It intercepts the dispatch flow and sets the Redis lock (`order:driver:lock:{id}`) to `CANCELLED`.
- It forcefully resets the driver's status back to `ONLINE` if they were already locked.
- If the driver attempts to accept exactly when the lock turns to `CANCELLED`, the system throws `IllegalStateException("Order was cancelled during acceptance.")` and halts the assignment.

### 6.2 Concurrent Updates (Optimistic Locking)
*Scenario:* Dispatch fails at the exact millisecond the Restaurant clicks "Start Cooking".
*Resolution:* 
- Customer Service processes `DISPATCH_FAILED` and transitions to `DELIVERY_FAILED`.
- Restaurant Service attempts to save `PREPARING` but hits an `ObjectOptimisticLockingFailureException`.
- The new retry mechanism intercepts this, waits, and re-reads the DB.
- Meanwhile, Customer Service emits `ORDER_STATUS_SYNC(DELIVERY_FAILED)`.
- Restaurant Service processes the sync, moving to `DELIVERY_FAILED`.
- The "Start Cooking" action is ultimately aborted or overridden by the terminal state.

### 6.2 Out-of-Order Events (Fast Participant, Slow Orchestrator)
*Scenario:* Restaurant rapidly accepts and starts preparing (`ORDER_ACCEPTED` followed immediately by `ORDER_PREPARING`). Customer Service processes `ORDER_PREPARING` before `ORDER_ACCEPTED`.
*Resolution:*
- Customer Service throws `IllegalStateTransitionException` because `PAID` state cannot jump directly to `PREPARING` without `ACCEPTED`.
- Orchestrator catches this and emits `ORDER_STATUS_SYNC(PAID)`.
- Restaurant Service receives `PAID`, compares sequence integers (`PAID` < `PREPARING`), and **gracefully ignores** the backward transition.
- Customer Service eventually processes the delayed `ORDER_ACCEPTED` and catches up.

### 6.3 Missing Events (Kafka Drop/Desync)
*Scenario:* Customer Service completely misses an event (e.g., `ORDER_READY`), leaving the system in a perpetual `PREPARING` state while Restaurant is in `READY`.
*Resolution:*
- Since state sequence checks prevent backward movement, the Restaurant remains in `READY`.
- **Manual Admin Intervention (Implemented)**: An admin can invoke the `/api/v1/internal/admin/orders/{orderId}/reconcile` endpoint in `CustomerApplication`. 
- The `AdminOrderController` polls the true state from the `RestaurantApplication` via its internal API (`/api/v1/internal/restaurants/orders/{orderId}/status`).
- If the restaurant's state sequence is higher than the customer app's state, it fast-forwards the state in `CustomerApplication` to match, restoring sync without any side effects.

### 6.4 Refund System Downtime
*Scenario:* Order is cancelled, but Payment Gateway is returning HTTP 500s.
*Resolution:*
- Saga uses the Outbox Pattern or explicit Kafka dead-letter queues (DLQ) with retries. 
- The refund event remains pending and is retried until the Payment Gateway comes back online.

### 6.5 Backward State Transition Prevention
*Scenario:* Due to a network replay or a manual admin trigger, an old `ORDER_ACCEPTED` event is re-processed on an order that is already `DELIVERED`.
*Resolution:*
- Both `CustomerApplication` and `RestaurantApplication` possess strict sequence state validation (`newStatus.getSequence() < currentStatus.getSequence()`).
- Attempting to go backward triggers an `IllegalStateException` and the transition is rejected, ensuring the terminal state remains intact.

### 6.6 State Fast-Forwarding (Missed Restaurant Steps)
*Scenario:* A restaurant forgets to click "Ready" (`READY_FOR_PICKUP`) on the tablet. The driver arrives, receives the food, obtains the pickup OTP from the restaurant, and enters it successfully in the app.
*Resolution:*
- The system attempts to update the state from `PREPARING` directly to `DISPATCHED`.
- Since the state sequence is monotonic (`PREPARING` 50 -> `DISPATCHED` 70), the sequence check `70 > 50` passes.
- The state seamlessly fast-forwards to `DISPATCHED`, preventing the order from being stuck due to a missed tablet interaction.

### 6.7 Enum Discrepancy Mapping During Sync
*Scenario:* `CustomerApplication` and `RestaurantApplication` bounded contexts use slightly different `OrderStatus` enums reflecting their local domain (e.g., `OUT_FOR_DELIVERY` vs `DISPATCHED`, `AWAITING_DELAY_APPROVAL` vs `ON_HOLD`). `CustomerApplication` sends an `ORDER_STATUS_SYNC` event with an out-of-context enum.
*Resolution:*
- `RestaurantOrderState` intercepts the sync string.
- Before calling `OrderStatus.valueOf()`, it explicitly translates these differing terminologies into its local equivalent.
- This mapping prevents an `IllegalArgumentException` from crashing the sync handler, keeping cross-service states eventually consistent.

### Implemented Fixes for Missing Scenarios
- **2.7 Saga Event Loss due to Exhausted Retries (Resilience Edge Case):** Configured Spring Kafka `DeadLetterPublishingRecoverer` to route exhausted retries to a `.DLQ` topic instead of dropping messages, preventing zombie state orders.
- **5.3 Driver Re-assignment (Driver Aborts):** Added a `/api/delivery/drivers/{driverId}/orders/{orderId}/abort` endpoint for assigned drivers to abort an order, which releases their assignment lock and emits an `ORDER_DRIVER_REJECTED` event to re-trigger candidate search.
- **6.6 State Fast-Forwarding:** Implemented `handleStatusUpdate` logic in `CustomerApplication`'s `OrderState` to correctly fast-forward the state if the new status sequence is monotonically increasing, thus preventing missed sequences (e.g. tablet click misses).
- **6.7 Enum Discrepancy Mapping During Sync:** Replaced hardcoded string evaluations with Enum usage using CommonLibrary Enums wherever possible. `RestaurantOrderState` explicitly intercepts and properly maps cross-boundary terminologies (e.g. `OUT_FOR_DELIVERY` vs `DISPATCHED`).
