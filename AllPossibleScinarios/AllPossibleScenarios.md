# Food Delivery System - All Possible Scenarios & Edge Cases

This document outlines all possible scenarios, state transitions, and edge cases for the Food Delivery microservices architecture, specifically focusing on the interaction between Customer, Restaurant, Delivery, and Payment services.

## 1. Happy Paths (Normal Execution)

### 1.1 Pre-Checkout Validation (Synchronous Checks)
Before an order is even persisted, the `CustomerOrderService` performs concurrent checks:
1. **Restaurant Check**: Fails immediately (`IllegalArgumentException` mapped to 400 Bad Request) if the restaurant is inactive or closed.
2. **Delivery Radius Check**: Fails if the distance (Haversine formula) between the restaurant and customer exceeds the maximum allowed radius.
3. **Fleet Availability Check**: Fails immediately (`DeliveryPartnerUnavailableException`) if Maps Integration reports zero available drivers nearby, preventing unfulfillable orders.
4. **Menu Item Availability Check**: Fails immediately (`MenuItemsUnavailableException`) if any requested menu items are unavailable or don't belong to the restaurant. The exception payload includes the unavailable item IDs so the UI can gracefully disable or remove them from the cart with a specific error message.

### 1.2 Standard End-to-End Success
1. Customer places order (`CREATED`).
2. Payment succeeds (`PAYMENT_SUCCESS` -> `OrderStatus.PAID`).
3. Restaurant auto-accepts or manually accepts (`OrderStatus.ACCEPTED`).
4. Restaurant starts cooking (`OrderStatus.PREPARING`).
5. Delivery service searches for driver (`DeliveryStatus.SEARCHING_FOR_DRIVER`).
6. Dispatcher finds a driver (`DeliveryStatus.ASSIGNED`).
7. Restaurant finishes cooking (`OrderStatus.READY_FOR_PICKUP`).
8. Driver picks up the food (`OrderStatus.HANDED_OVER`, `DeliveryStatus.OUT_FOR_DELIVERY`).
9. Driver delivers the food to the customer (`DeliveryStatus.DELIVERED`).

### 1.3 Success with Restaurant Delay (Approved)
1. Customer places order -> Payment succeeds.
2. Restaurant needs more time and requests a delay (`OrderStatus.AWAITING_DELAY_APPROVAL`).
3. Customer receives notification and **approves** the delay.
4. Order resumes normal flow (`ACCEPTED` -> `PREPARING` -> `READY_FOR_PICKUP` -> `HANDED_OVER`).

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
4. **Bug Resolved**: `OrderSagaOrchestrator.handlePaymentEvents` in `CustomerApplication` historically consumed the event but failed to check the `eventType`. This has been fixed to strictly validate the payload type.

### 2.7 Saga Event Loss due to Exhausted Retries (Resilience Edge Case)
1. `OrderSagaOrchestrator` consumes a valid event from Kafka.
2. Concurrent database updates cause an `ObjectOptimisticLockingFailureException`.
3. The orchestrator catches this and retries up to `MAX_OPTIMISTIC_LOCK_RETRIES` (default 3 times).
4. If retries are exhausted, the event is routed to a `.DLQ` (Dead Letter Queue) topic instead of being dropped, preventing zombie states.

### 2.8 Late Payment Success on Cancelled Order
1. Order is placed but payment gets delayed.
2. System cancels the order due to timeout (`CANCELLED`).
3. Payment gateway successfully processes the payment late and fires `PAYMENT_SUCCESS`.
4. `TerminalState` issues an automatic immediate refund, unless cancellation was a customer penalty.

### 2.9 Partial Refunds (Item Unavailable)
1. Order is paid. Restaurant cannot fulfill a specific item but can fulfill the rest.
2. Restaurant initiates a partial refund for the specific item via an API.
3. System refunds food cost/tax proportionally, leaving delivery/platform fee untouched.
4. Order total is updated, `PARTIAL_REFUND` event is emitted.

---

## 3. Restaurant Rejection & Cancellation Scenarios

### 3.1 Upfront Rejection
1. Payment succeeds (`PAID`).
2. Restaurant manually rejects the order (e.g., out of stock).
3. Status changes to `CANCELLED_BY_RESTAURANT`.
4. Saga triggers a full refund (`CANCELLED_AND_REFUNDED`).

### 3.2 Mid-Preparation Cancellation
1. Restaurant accepts and starts preparing (`PREPARING`).
2. An unexpected issue occurs (e.g., equipment failure) and Restaurant cancels.
3. Status changes to `CANCELLED_BY_RESTAURANT`.
4. Saga triggers full refund. Delivery Service is notified to abort dispatch.

### 3.3 Restaurant Timeout (Auto-Cancel)
1. Payment succeeds (`PAID`).
2. Restaurant fails to accept/reject within SLA (e.g., 5-10 minutes).
3. System automatically cancels (`CANCELLED`). Full refund triggered.

---

## 4. Delay Approval Scenarios (Customer Side)

### 4.1 Delay Rejected by Customer
1. Restaurant requests extra prep time (`AWAITING_DELAY_APPROVAL`).
2. Customer is unhappy and **rejects** it.
3. Order is immediately `CANCELLED_BY_RESTAURANT`.
4. Full refund triggered.

### 4.2 Delay Timeout (Customer Unresponsive)
1. Restaurant requests extra prep time.
2. Customer does not respond within the time limit.
3. System automatically changes to `CANCELLED_BY_RESTAURANT`. Full refund triggered.

### 4.3 Customer Initiated Cancellation (Pre-Acceptance)
1. Customer places order and pays.
2. Customer cancels order *before* the restaurant accepts it.
3. Order is `CANCELLED`. Full refund triggered.

---

## 5. Dispatch, Delivery & Manual Intervention Scenarios

### 5.1 Maps Dispatch Candidate Search (Micro-Interaction)
1. Delivery Service starts searching for a driver.
2. Maps Integration identifies a candidate and emits `DISPATCH_CANDIDATE_FOUND`.
3. Specific driver receives a ping.
4. If driver rejects/ignores ping, Delivery Service emits `ORDER_DRIVER_REJECTED` and re-enters the loop.

### 5.2 Complete Dispatch Failure (Admin Intervention Workflow)
**Crucial Architectural Update**: Dispatch failures no longer overwrite `OrderStatus`, preserving restaurant state.
1. Restaurant accepts or starts preparing.
2. Delivery Service repeatedly fails to find a driver (e.g., zero candidates).
3. Delivery Service emits `DISPATCH_FAILED`.
4. Customer Service marks the order's `DeliveryStatus` as `FAILED`. **`OrderStatus` remains completely untouched** (e.g., `PREPARING` or `READY_FOR_PICKUP`).
5. Order enters the Admin Intervention Queue on the Admin Portal.
6. The Restaurant UI continues to show the order's actual food preparation state, completely unaffected by the delivery delay.

### 5.3 Admin Manual Resolution
Following a Dispatch Failure (`DeliveryStatus.FAILED`), the admin has two choices:
1. **Manual Driver Assignment:** Admin assigns a specific driver. `DeliveryStatus` moves to `ASSIGNED`. A `DRIVER_ASSIGNED` event is fired. The driver proceeds to the restaurant.
2. **Manual Cancellation:** Admin decides it cannot be delivered. Admin issues an `ORDER_CANCELLED_BY_ADMIN` event. The order fully aborts, customer is refunded, and restaurant is notified.

### 5.4 Driver Re-assignment (Driver Aborts)
1. Driver is assigned (`DeliveryStatus.ASSIGNED`).
2. Driver cancels the assignment (flat tire, emergency) via `/api/delivery/drivers/{driverId}/orders/{orderId}/abort`.
3. System releases lock and emits `ORDER_DRIVER_REJECTED`. New driver is found.

### 5.5 Delivery Failure (Customer Unreachable)
1. Driver picks up food (`DeliveryStatus.OUT_FOR_DELIVERY`).
2. Driver reaches location but cannot contact the customer.
3. Driver marks delivery as failed. Status changes to `DELIVERY_FAILED`.
4. No refund or partial refund issued depending on business policy.

### 5.6 Driver Abandons Delivery (Timeout)
1. Driver picks up food. No updates received for over 2 hours.
2. `AbandonedDeliverySweeper` cron job detects stale order.
3. Order is marked as `DELIVERY_FAILED`. Refund/support flow initiated.

### 5.7 OTP Validation Failures
- **Wrong Pickup OTP**: Driver enters wrong OTP at restaurant. Throws `IllegalStateTransitionException`. Cannot proceed to `OUT_FOR_DELIVERY`.
- **Wrong Delivery OTP**: Driver enters wrong OTP at customer location. Cannot proceed to `DELIVERED`.

### 5.8 Driver Accepts Order Early
1. Delivery searches for driver while restaurant is `ACCEPTED` or `PREPARING`.
2. Driver accepts. `DeliveryStatus` -> `ASSIGNED`.
3. Driver waits at restaurant until `OrderStatus` becomes `READY_FOR_PICKUP`.

---

## 6. Edge Cases & Race Conditions (Saga Sync)

### 6.1 Cancellation Race Condition during Dispatch (Delivery Lock)
*Scenario:* Restaurant cancels order midway, but a driver is simultaneously accepting the dispatch ping.
*Resolution:*
- `DeliveryExecutiveApplication` receives terminal cancellation event.
- Intercepts dispatch flow, sets Redis lock (`order:driver:lock:{id}`) to `CANCELLED`.
- If driver attempts to accept exactly when lock turns to `CANCELLED`, throws `IllegalStateException`.

### 6.2 Concurrent Updates (Optimistic Locking)
*Scenario:* Admin manually assigns a driver (`DeliveryStatus` update) at the exact millisecond Restaurant clicks "Start Cooking" (`OrderStatus` update).
*Resolution:*
- Because `OrderStatus` and `DeliveryStatus` updates are largely isolated to different fields, conflicts are minimized.
- If an `ObjectOptimisticLockingFailureException` occurs on the entity, the retry mechanism re-reads the DB and applies the state.

### 6.3 Out-of-Order Events (Fast Participant, Slow Orchestrator)
*Scenario:* Restaurant rapidly accepts and starts preparing. Customer Service processes `ORDER_PREPARING` before `ORDER_ACCEPTED`.
*Resolution:*
- Customer Service throws `IllegalStateTransitionException` because `PAID` cannot jump directly to `PREPARING`.
- Orchestrator catches this and emits `ORDER_STATUS_SYNC(PAID)`.
- Restaurant Service receives `PAID`, compares sequence integers, and ignores the backward transition. Customer Service eventually catches up.

### 6.4 Missing Events (Kafka Drop/Desync)
*Scenario:* Customer Service completely misses an event (e.g., `ORDER_READY`), leaving system in `PREPARING` while Restaurant is `READY_FOR_PICKUP`.
*Resolution:*
- Admin invokes `/api/v1/internal/admin/orders/{orderId}/reconcile` in `CustomerApplication`.
- `AdminOrderController` polls true state from `RestaurantApplication`.
- Fast-forwards state in `CustomerApplication` to match.

### 6.5 Backward State Transition Prevention
*Scenario:* An old `ORDER_ACCEPTED` event is re-processed on an order that is already `DELIVERED`.
*Resolution:*
- Both applications possess strict sequence state validation.
- Attempting to go backward triggers an `IllegalStateException` and the transition is rejected.

### 6.6 State Fast-Forwarding (Missed Restaurant Steps)
*Scenario:* Restaurant forgets to click "Ready". Driver arrives, gets food, obtains pickup OTP from restaurant, enters it successfully.
*Resolution:*
- System attempts to update state from `PREPARING` directly to `HANDED_OVER`.
- Monotonic sequence check allows the jump. State seamlessly fast-forwards.

### 6.7 Enum Discrepancy Mapping During Sync
*Scenario:* Bounded contexts use different terminologies for similar events.
*Resolution:*
- `RestaurantOrderState` intercepts the sync string and translates terminologies into its local equivalent before calling `.valueOf()`.
