# Food Delivery System - State Change Scenarios

This document outlines the detailed state transition sequences across the three microservices (Customer, Restaurant, Delivery) to ensure strict consistency and graceful handling of race conditions and edge cases.

## 1. Happy Path Sequence
This is the standard flow of an order from creation to successful delivery.

1. **Order Placed**: Customer app creates an order `CREATED`.
2. **Payment Success**: Customer app transitions order to `PENDING_ACCEPTANCE` -> Publishes `ORDER_PAID`.
3. **Restaurant Receives**: Restaurant app handles `ORDER_PAID` -> Creates order as `CREATED`.
4. **Restaurant Accepts**: Restaurant app transitions to `ACCEPTED` -> Publishes `ORDER_ACCEPTED`.
   - **Customer App**: Updates to `ACCEPTED`.
   - **Delivery App**: Calculates dispatch time. If immediate, triggers `DRIVER_ASSIGNED`.
5. **Driver Assignment**: Delivery App publishes `DRIVER_ASSIGNED`.
   - **Customer & Restaurant App**: Updates `deliveryExecutiveId` and displays "Rider assigned".
6. **Restaurant Prepares**: Restaurant app transitions to `PREPARING` -> Publishes `ORDER_PREPARING`.
   - **Customer App**: Updates to `PREPARING`.
   - **Delivery App**: Syncs restaurant status for Rider UI.
7. **Rider Arrives**: Rider clicks "Reached Restaurant" -> Publishes `ORDER_AT_RESTAURANT`.
   - **Customer & Restaurant App**: Updates `deliveryStatus = AT_RESTAURANT`.
8. **Restaurant Ready**: Restaurant transitions to `READY` -> Publishes `ORDER_READY`.
   - **Customer App**: Updates to `READY_FOR_PICKUP`.
   - **Delivery App**: Syncs restaurant status, unlocking the "Confirm Pickup" button in Rider UI.
9. **Rider Picks Up**: Rider enters OTP and clicks "Confirm Pickup" -> Publishes `ORDER_STATUS_UPDATED (OUT_FOR_DELIVERY)`.
   - **Customer App**: Transitions to `PICKED_UP`, `deliveryStatus = OUT_FOR_DELIVERY`.
   - **Restaurant App**: Transitions to `DISPATCHED`, `deliveryStatus = OUT_FOR_DELIVERY`.
10. **Rider Delivers**: Rider enters delivery OTP -> Publishes `ORDER_STATUS_UPDATED (DELIVERED)`.
    - **Customer & Restaurant App**: Transitions to `DELIVERED`, `deliveryStatus = DELIVERED`. Ledger updates execute.

---

## 2. Timing Edge Cases & Race Conditions

### Edge Case 1: Early Rider Arrival
- **Scenario:** The driver is assigned immediately upon the restaurant accepting the order (state `ACCEPTED`). The restaurant is geographically close, and the rider clicks "Arrived at Restaurant" before the restaurant has even started preparing (still `ACCEPTED`) or while preparing (state `PREPARING`).
- **Implementation Guarantee:** `handleDriverAtRestaurant` is implemented in all non-terminal states (`AcceptedState`, `PreparingState`, `ReadyState`) in both the Customer and Restaurant apps. The event sets `deliveryStatus = AT_RESTAURANT` while keeping the primary order status (e.g., `PREPARING`) intact. Neither state machine drops the event.

### Edge Case 2: Out of Order Kafka Events
- **Scenario:** Can the `OUT_FOR_DELIVERY` event arrive at the Customer app before the `ORDER_READY` event from the restaurant? 
- **Implementation Guarantee:** No. The Rider UI strictly enforces that the "Confirm Pickup" button cannot be triggered until the Delivery App receives the `ORDER_READY` event from the restaurant. This acts as a physical block, ensuring that `ORDER_READY` is fully published and consumed by the Delivery App *before* the Delivery App can publish `OUT_FOR_DELIVERY`. Furthermore, Kafka guarantees sequential ordering per `orderId` partition.

### Edge Case 3: Restaurant Cancels After Rider Assignment
- **Scenario:** The restaurant accepts the order, a rider is assigned, but the restaurant subsequently cancels the order (e.g., out of stock).
- **Implementation Guarantee:** The Restaurant app publishes `ORDER_CANCELLED_BY_RESTAURANT`. 
  - **Delivery App:** Consumes this event (via `TerminalStateStrategy`), frees the rider, sets rider status back to `AVAILABLE`, and clears active jobs.
  - **Customer App:** Transitions order to `CANCELLED_BY_RESTAURANT`, triggers a refund, and notifies the customer.

### Edge Case 4: Rider Unavailable / Dispatch Failure
- **Scenario:** The restaurant accepts the order, but no riders are available in the vicinity. The dispatch loop retries but ultimately fails.
- **Implementation Guarantee:** The Delivery App publishes `DISPATCH_FAILED` after maximum retries.
  - **Customer App:** Consumes `DISPATCH_FAILED`, transitions to `DELIVERY_FAILED`, triggers a full refund.
  - **Restaurant App:** Consumes `DISPATCH_FAILED`, transitions to `DELIVERY_FAILED` (terminal state), allowing the restaurant to dispose of the food or halt preparation.

### Edge Case 5: Rider Reports Customer Unavailable
- **Scenario:** The rider arrives at the customer's location but the customer is unresponsive. Rider marks delivery as failed.
- **Implementation Guarantee:** Delivery App publishes `ORDER_STATUS_UPDATED (FAILED)`.
  - **Customer App:** Consumes this event via `PickedUpState.handleDeliveryFailed`, sets status to `DELIVERY_FAILED`, and triggers a refund (since food was not delivered).
  - **Restaurant App:** Consumes via `DispatchedState.handleDeliveryFailed` and marks its local copy as `DELIVERY_FAILED`. 

---

### Edge Case 6: Fast-forwarding and Backward Transition Prevention
- **Scenario:** A rider bypasses the typical flow (e.g., using a raw API call) and marks an order as `PICKED_UP` or `OUT_FOR_DELIVERY` while the restaurant hasn't marked it `READY` yet, or conversely, a delayed `ORDER_AT_RESTAURANT` event arrives after the order is already dispatched.
- **Implementation Guarantee:** 
  - **Backward Transitions:** `handleDriverAtRestaurant` logic in `RestaurantOrderState` explicitly checks if the status is `DISPATCHED` (or terminal) and returns early, preventing the `deliveryStatus` from reverting from `OUT_FOR_DELIVERY` back to `AT_RESTAURANT`.
  - **Fast-forwarding:** Both `CustomerApplication` (`handleStatusUpdate`) and `RestaurantApplication` (`handleOrderStatusUpdated`) implement sequence-based checking. If an `OUT_FOR_DELIVERY` event arrives while the app is in `ACCEPTED` or `PREPARING`, the status immediately fast-forwards to `PICKED_UP` / `DISPATCHED` and properly sets `deliveryStatus` to `OUT_FOR_DELIVERY`, ensuring the apps never get stuck in a stale state.

### Edge Case 7: Stale Cache Reversion
- **Scenario:** A delayed `ORDER_PREPARING` event arrives at the Delivery Executive application *after* the restaurant has already sent an `ORDER_READY` event. The Delivery App caches this restaurant status to enable/disable the rider's "Confirm Pickup" UI button.
- **Implementation Guarantee:** `OrderStatusUpdatedStrategy` in the Delivery App now implements sequence-checking. It evaluates the sequence value of the newly arrived event against the cached status. If the incoming event's sequence is lower (a backward transition), it safely ignores the event and logs a warning. This prevents the Rider UI from inexplicably reverting from "Ready" back to "Preparing" and breaking the pickup flow.

### Edge Case 8: Delivery Executive Cancellation Cleanup
- **Scenario**: The user cancels the order (`CustomerApplication` -> `ORDER_CANCELLED`), but the `DeliveryExecutiveApplication` had a driver assigned or pending a dispatch ping.
- **Issue**: The driver lock in Redis (`order:driver:lock:ORDER_ID`) and the pending ping `order:ping:pending:ORDER_ID` would remain orphaned if the driver app didn't explicitly clean it up when it transitions to a terminal state (`ORDER_CANCELLED`).
- **Fix**: Implemented cleanup logic in `TerminalStateStrategy.java` in the `DeliveryExecutiveApplication` so that when `ORDER_CANCELLED` is received via Kafka, all Redis locks and pending pings are removed, and the driver is released back to the available pool.

### Edge Case 9: OTP Resilience Mismatch (Redis Fallback)
- **Scenario**: A driver marks an order as picked up or delivered, but the `DeliveryExecutiveApplication`'s Redis cache (which stores the original `dispatchPayload` containing the OTPs) lost the payload due to eviction or a crash.
- **Issue**: The `DeliveryExecutiveApplication` implements a resilience fallback: if the payload is missing from Redis, it skips OTP validation and trusts the driver to prevent them from being stuck with the food. However, the `CustomerApplication` originally strictly validated the `pickupOtp` and `deliveryOtp`. If the CustomerApp rejected the transition due to a missing/invalid OTP in the event payload, it would stay stuck in `READY_FOR_PICKUP` or `PICKED_UP`, while the DeliveryApp successfully transitioned to `OUT_FOR_DELIVERY` or `DELIVERED`, leading to a split brain state.
- **Fix**: Removed OTP validation from `ReadyForPickupState.java` and `PickedUpState.java` in the `CustomerApplication`. The `DeliveryExecutiveApplication` is now the authoritative source for delivery state transitions. If it deems a delivery successful (either via standard OTP validation or fallback), the `CustomerApplication` will respect the `ORDER_DELIVERED` Kafka event and sync its state.

---

## 3. Strict State Transition Enforcement
The `OrderState` (Customer) and `RestaurantOrderState` (Restaurant) interfaces utilize the **State Design Pattern**. 
- Any event received out-of-bounds or backward (e.g. receiving an `ORDER_PAID` event while in `PREPARING` state) throws an `IllegalStateTransitionException`.
- The `OrderSagaOrchestrator` consumer catches these exceptions gracefully, logs a warning, and if applicable, emits an `ORDER_STATUS_SYNC` event to correct the sender, avoiding system crashes or unacknowledged messages.
- This strictly enforces monotonically increasing state progressions, preventing transient network replays or malicious API calls from reverting an order's lifecycle.

---

## 4. Payment and Order Lifecycle Decoupling
To avoid "zombie" states and an explosion of enum values, the **Financial Lifecycle** and the **Delivery Lifecycle** are strictly decoupled:
- The `OrderStatus` purely reflects the physical fulfillment state (e.g., `CREATED`, `PENDING_ACCEPTANCE`, `ACCEPTED`, `CANCELLED`).
- The `PaymentStatus` purely reflects the financial state (e.g., `PENDING`, `SUCCESS`, `REFUNDING`, `REFUNDED`).

### Edge Case 8: Cancellation and Refunding Independence
- **Scenario:** The restaurant cancels an order after it has been paid by the customer.
- **Implementation Guarantee:** The order's `OrderStatus` transitions immediately to `CANCELLED_BY_RESTAURANT`, effectively ending the fulfillment lifecycle. Asynchronously, the Saga orchestrator processes the payment refund. When the refund completes, it updates *only* the `PaymentStatus` to `REFUNDED`. It does NOT attempt to overwrite the `OrderStatus`, meaning the database clearly records *why* the order was cancelled (`CANCELLED_BY_RESTAURANT`) alongside the fact that the customer was `REFUNDED`.

### Edge Case 9: Global Exception Handling for Invalid State Transitions
- **Scenario:** An invalid state transition is triggered via API (e.g., trying to mark an already `CANCELLED` order as `READY_FOR_PICKUP`).
- **Implementation Guarantee:** The state machines throw an `IllegalStateTransitionException`. This exception extends `IllegalStateException`, which is intercepted by the `GlobalExceptionHandler` (via `@RestControllerAdvice`). The backend returns an HTTP 400 Bad Request with the precise error message. The frontend UI (Customer, Restaurant, Delivery dashboards) catches this error during the `apiPost` call, reverts any optimistic UI updates, and displays the exact backend error message to the user via a Toast or Alert, ensuring the user is immediately aware of the failure without generic 500 errors.

### Edge Case 11: Concurrent Dispatch Loop Resurgence Post-Cancellation
**Scenario**: A `DELIVERY_FAILED` or `ORDER_CANCELLED` event arrives in the Delivery App Kafka listener, triggering `TerminalStateStrategy` to perform cleanup. The cleanup previously explicitly deleted the `order:dispatch:lock:[ORDER_ID]`. However, since `DELIVERY_FAILED` sets a 24-hour dispatch lock preventing further ping iterations, deleting it exposed a race condition where a stray delayed Kafka event could theoretically initiate a new dispatch ping cycle for a cancelled order.
**Resolution**: Modified `TerminalStateStrategy.java` in `DeliveryExecutiveApplication`. Instead of `redisTemplate.delete(...)`, it now explicitly sets `order:dispatch:lock` to `"CANCELLED"` with a 24-hour expiration (`redisTemplate.opsForValue().set(..., "CANCELLED", Duration.ofHours(24))`). This securely prevents any new dispatch loops from acquiring the lock for terminal orders.
