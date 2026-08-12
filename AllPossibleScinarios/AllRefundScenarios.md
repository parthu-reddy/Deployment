# Food Delivery System — All Possible Refund Scenarios & Edge Cases

> This document exhaustively catalogues every scenario in which a refund (full or partial) is triggered, processed, or should be considered across the Food Delivery platform. Each scenario is mapped to the state machine implementation, the responsible service, and the financial flow.

---

## Table of Contents

1. [Refund Architecture Overview](#1-refund-architecture-overview)
2. [Full Refund Scenarios (Pre-Preparation)](#2-full-refund-scenarios-pre-preparation)
3. [Full Refund Scenarios (During Preparation)](#3-full-refund-scenarios-during-preparation)
4. [Full Refund Scenarios (Post-Preparation / Delivery Phase)](#4-full-refund-scenarios-post-preparation--delivery-phase)
5. [Full Refund Scenarios (Admin-Initiated)](#5-full-refund-scenarios-admin-initiated)
6. [Partial Refund Scenarios](#6-partial-refund-scenarios)
7. [Delay Approval Flow Refunds](#7-delay-approval-flow-refunds)
8. [Late Payment on Cancelled Order (Automatic Refund)](#8-late-payment-on-cancelled-order-automatic-refund)
9. [Refund Failure & Recovery Scenarios](#9-refund-failure--recovery-scenarios)
10. [Refund Idempotency & Duplicate Prevention](#10-refund-idempotency--duplicate-prevention)
11. [Wallet Refund Scenarios](#11-wallet-refund-scenarios)
12. [Ledger Reversal Scenarios](#12-ledger-reversal-scenarios)
13. [Refund Webhook Processing Scenarios](#13-refund-webhook-processing-scenarios)
14. [Edge Cases & Race Conditions](#14-edge-cases--race-conditions)
15. [Scenarios Where NO Refund is Issued](#15-scenarios-where-no-refund-is-issued)
16. [Payment Intent Status Lifecycle](#16-payment-intent-status-lifecycle)
17. [Refund Amount Calculation Rules](#17-refund-amount-calculation-rules)

---

## 1. Refund Architecture Overview

### Services Involved in Refund Processing

| Service | Role in Refund Flow |
|---|---|
| **CustomerApplication** (Saga Orchestrator) | Determines if refund is needed via `OrderContext.requiresRefund`. Publishes `PAYMENT_REFUND_REQUESTED` and `REFUND_GENERATED` outbox events. Records ledger transactions on refund confirmation. |
| **PaymentGatewayIntegration** | Consumes `PAYMENT_REFUND_REQUESTED`, calls the gateway strategy (`IPaymentGatewayStrategy.initiateRefund()`), processes `refund.success` webhook, emits `PAYMENT_REFUNDED` / `PAYMENT_PARTIALLY_REFUNDED` back via outbox. |
| **WalletService** | Consumes `REFUND_GENERATED` events, credits the customer wallet. Provides idempotent `reverseDebit()` for failed ledger reversals. |
| **LedgerService** | Records the REFUND ledger entry (Platform → Customer) when `PAYMENT_REFUNDED` is confirmed. |

### PaymentIntentStatus Lifecycle (Refund-Related)

```
SUCCESS(40) / CAPTURED(60)
    ↓ (processRefund triggered)
REFUND_PENDING(100)
    ↓ (gateway confirms refund)
REFUNDED(90)           — if amountRefunded >= original amount
PARTIALLY_REFUNDED(80) — if amountRefunded < original amount
    ↓ (if gateway/outbox fails)
REFUND_FAILED(110)     — allows retry
```

### Key Constants
- `REFUND_TX_PREFIX = "REFUND_"` — Used for deterministic transfer ID generation
- `PLATFORM_ACCOUNT_ID` — Platform's master account (source of refund funds)
- `ChargeCategory.REFUND` — Ledger charge category for refund entries
- Optimistic lock retries: `MAX_OPTIMISTIC_LOCK_RETRIES = 3`

---

## 2. Full Refund Scenarios (Pre-Preparation)

### 2.1 Restaurant Upfront Rejection (PENDING_ACCEPTANCE → CANCELLED_BY_RESTAURANT)

**Trigger:** Restaurant rejects the order immediately after payment succeeds.

| Attribute | Value |
|---|---|
| **State Transition** | `PENDING_ACCEPTANCE` → `CANCELLED_BY_RESTAURANT` |
| **State Handler** | `PendingAcceptanceState.handleOrderCancelledByRestaurant()` |
| **Refund Type** | Full refund of `order.getTotalAmount()` |
| **Refund Trigger** | `ctx.setRequiresRefund(true)` |
| **Who Initiated** | Restaurant |
| **Customer Notification** | `ORDER_CANCELLED_BY_RESTAURANT` |

**Financial Flow:**
1. Ledger: Platform → Customer (full `totalAmount`, category: `REFUND`)
2. Payment Gateway: `PAYMENT_REFUND_REQUESTED` → gateway refund → `refund.success` webhook
3. Wallet: `REFUND_GENERATED` event → customer wallet credited

---

### 2.2 Customer Cancellation Before Restaurant Accepts (PENDING_ACCEPTANCE → CANCELLED)

**Trigger:** Customer cancels before the restaurant has accepted.

| Attribute | Value |
|---|---|
| **State Transition** | `PENDING_ACCEPTANCE` → `CANCELLED` |
| **State Handler** | `PendingAcceptanceState.cancelByCustomer()` |
| **Refund Type** | Full refund |
| **Refund Trigger** | `ctx.setRequiresRefund(true)` — "Full refund when customer cancels before restaurant accepts" |
| **Who Initiated** | Customer |
| **Additional Action** | `emitOrderCancelledByCustomerEvent()` notifies restaurant |

---

### 2.3 Restaurant Timeout / Auto-Cancel (PENDING_ACCEPTANCE → CANCELLED_BY_RESTAURANT)

**Trigger:** Restaurant fails to accept/reject within SLA (5–10 minutes). System auto-cancels.

| Attribute | Value |
|---|---|
| **State Transition** | `PENDING_ACCEPTANCE` → `CANCELLED_BY_RESTAURANT` |
| **Refund Type** | Full refund |
| **Mechanism** | Scheduled sweeper or timeout job fires `ORDER_CANCELLED_BY_RESTAURANT` |

---

### 2.4 Admin Cancellation on PENDING_ACCEPTANCE Order

**Trigger:** Admin cancels an order that is still awaiting restaurant acceptance.

| Attribute | Value |
|---|---|
| **State Transition** | `PENDING_ACCEPTANCE` → `CANCELLED` |
| **State Handler** | `PendingAcceptanceState.handleOrderCancelledByAdmin()` |
| **Refund Type** | Full refund |
| **Refund Trigger** | `ctx.setRequiresRefund(true)` |

---

### 2.5 Admin Cancellation on CREATED Order with Successful Payment

**Trigger:** Admin cancels an order still in `CREATED` state, but payment has already succeeded.

| Attribute | Value |
|---|---|
| **State Transition** | `CREATED` → `CANCELLED` |
| **State Handler** | `CreatedState.handleOrderCancelledByAdmin()` |
| **Refund Condition** | `if (order.getPaymentStatus() == PaymentIntentStatus.SUCCESS)` → `ctx.setRequiresRefund(true)` |
| **Edge Case** | If payment hasn't succeeded yet, **no refund** is issued (nothing to refund). |

---

## 3. Full Refund Scenarios (During Preparation)

### 3.1 Restaurant Cancels After Accepting (ACCEPTED → CANCELLED_BY_RESTAURANT)

**Trigger:** Restaurant accepted but then cancels (e.g., out of ingredients discovered late).

| Attribute | Value |
|---|---|
| **State Transition** | `ACCEPTED` → `CANCELLED_BY_RESTAURANT` |
| **State Handler** | `AcceptedState.handleOrderCancelledByRestaurant()` |
| **Refund Type** | Full refund |
| **Additional Action** | Delivery Service notified to abort dispatch if in progress |

---

### 3.2 Restaurant Cancels Mid-Preparation (PREPARING → CANCELLED_BY_RESTAURANT)

**Trigger:** Equipment failure, ingredient issues, or other unexpected issue during cooking.

| Attribute | Value |
|---|---|
| **State Transition** | `PREPARING` → `CANCELLED_BY_RESTAURANT` |
| **State Handler** | `PreparingState.handleOrderCancelledByRestaurant()` |
| **Refund Type** | Full refund |
| **Refund Trigger** | `ctx.setRequiresRefund(true)` |

---

### 3.3 Admin Cancels During ACCEPTED State

| Attribute | Value |
|---|---|
| **State Transition** | `ACCEPTED` → `CANCELLED` |
| **State Handler** | `AcceptedState.handleOrderCancelledByAdmin()` |
| **Refund Type** | Full refund |

---

### 3.4 Admin Cancels During PREPARING State

| Attribute | Value |
|---|---|
| **State Transition** | `PREPARING` → `CANCELLED` |
| **State Handler** | `PreparingState.handleOrderCancelledByAdmin()` |
| **Refund Type** | Full refund |

---

## 4. Full Refund Scenarios (Post-Preparation / Delivery Phase)

### 4.1 Restaurant Cancels After Food is Ready (READY_FOR_PICKUP → CANCELLED_BY_RESTAURANT)

**Trigger:** Extremely rare — food is ready but restaurant discovers a critical issue (e.g., contamination, wrong order prepared).

| Attribute | Value |
|---|---|
| **State Transition** | `READY_FOR_PICKUP` → `CANCELLED_BY_RESTAURANT` |
| **State Handler** | `ReadyForPickupState.handleOrderCancelledByRestaurant()` |
| **Refund Type** | Full refund |

---

### 4.2 Admin Cancels While READY_FOR_PICKUP

| Attribute | Value |
|---|---|
| **State Transition** | `READY_FOR_PICKUP` → `CANCELLED` |
| **State Handler** | `ReadyForPickupState.handleOrderCancelledByAdmin()` |
| **Refund Type** | Full refund |
| **Common Reason** | Dispatch failed and admin decides to cancel rather than manually assign |

---

### 4.3 Delivery Failed After Food Picked Up (HANDED_OVER + DELIVERY_FAILED)

**Trigger:** Driver picks up food but fails to deliver (customer unreachable, address invalid, driver vehicle breakdown).

| Attribute | Value |
|---|---|
| **State Transition** | `DeliveryStatus.OUT_FOR_DELIVERY` → `DeliveryStatus.FAILED` |
| **State Handler** | `HandedOverState.handleDeliveryFailed()` |
| **Refund Type** | Full refund |
| **Note** | `OrderStatus` remains `HANDED_OVER`, only `DeliveryStatus` changes to `FAILED` |
| **Customer Notification** | `DELIVERY_FAILED` |

---

### 4.4 Driver Abandons Delivery — Timeout (AbandonedDeliverySweeper)

**Trigger:** Driver picks up food, then goes silent for > 2 hours. The `AbandonedDeliverySweeper` cron job detects the stale order.

| Attribute | Value |
|---|---|
| **State Transition** | `DeliveryStatus.OUT_FOR_DELIVERY` → `DeliveryStatus.FAILED` |
| **Mechanism** | `AbandonedDeliverySweeper` runs every 5 minutes, emits `DELIVERY_FAILED` for HANDED_OVER orders older than 2 hours |
| **Refund Type** | Full refund |
| **Admin Action** | Order enters admin intervention queue. Admin can issue final cancellation. |

---

### 4.5 Admin Cancels After Food Handed Over (HANDED_OVER → CANCELLED)

**Trigger:** After driver picks up food, admin determines order cannot be completed (e.g., driver confirmed lost, food damaged).

| Attribute | Value |
|---|---|
| **State Transition** | `HANDED_OVER` → `CANCELLED` |
| **State Handler** | `HandedOverState.handleOrderCancelledByAdmin()` |
| **Refund Type** | Full refund |
| **Cancellation Reason** | "Cancelled by Admin (Delivery abandoned or failed)" |

---

### 4.6 Delivery Failed While READY_FOR_PICKUP (Driver Not Yet Picked Up)

**Trigger:** Driver reports delivery failure even before pickup completes (unusual but possible — e.g., driver marks failure due to restaurant closure).

| Attribute | Value |
|---|---|
| **State Transition** | `DeliveryStatus` → `FAILED` |
| **State Handler** | `ReadyForPickupState.handleDeliveryFailed()` |
| **Refund Type** | Full refund |
| **Refund Trigger** | `ctx.setRequiresRefund(true)` |

---

## 5. Full Refund Scenarios (Admin-Initiated)

Admin can cancel orders at **any** non-terminal state. Every state handler's `handleOrderCancelledByAdmin()` sets `requiresRefund = true`, **except**:
- `CreatedState` — which conditionally checks `PaymentIntentStatus.SUCCESS` first (since payment may not have been made yet).

### Summary Table

| State at Cancellation | Handler Class | Refund? | Condition |
|---|---|---|---|
| `CREATED` | `CreatedState` | Conditional | Only if `PaymentIntentStatus.SUCCESS` |
| `PENDING_ACCEPTANCE` | `PendingAcceptanceState` | ✅ Always | — |
| `ACCEPTED` | `AcceptedState` | ✅ Always | — |
| `PREPARING` | `PreparingState` | ✅ Always | — |
| `AWAITING_DELAY_APPROVAL` | `AwaitingDelayApprovalState` | ✅ Always | — |
| `READY_FOR_PICKUP` | `ReadyForPickupState` | ✅ Always | — |
| `HANDED_OVER` | `HandedOverState` | ✅ Always | — |
| Terminal (`DELIVERED`, `CANCELLED`) | `TerminalState` | ❌ Ignored | Admin cancel on terminal is a no-op |

---

## 6. Partial Refund Scenarios

### 6.1 Menu Item Unavailable After Order Accepted

**Trigger:** Restaurant can fulfill most items but one or more items are unavailable.

| Attribute | Value |
|---|---|
| **Method** | `OrderSagaOrchestrator.processPartialRefund(order, partialAmount)` |
| **Eligible Statuses** | `SUCCESS`, `CAPTURED`, `PARTIALLY_REFUNDED`, `REFUND_FAILED` |
| **Refund Scope** | Food cost + proportional tax for the specific unavailable item(s). Delivery fee and platform fee remain untouched. |
| **Event Emitted** | `PAYMENT_REFUND_REQUESTED` (with partial `amountInInr`) |
| **Post-Refund Status** | `PaymentIntentStatus.REFUND_PENDING` → eventually `PARTIALLY_REFUNDED` |

### 6.2 Multiple Sequential Partial Refunds

**Trigger:** Multiple items become unavailable at different times, each triggering a separate partial refund.

| Attribute | Value |
|---|---|
| **Handling** | Each partial refund adds to `PaymentIntent.amountRefunded` cumulatively |
| **Status Logic** | `if (amountRefunded >= originalAmount)` → `REFUNDED`; else → `PARTIALLY_REFUNDED` |
| **Idempotency** | Transfer IDs include unique suffix: `REFUND_TX_PREFIX + "PARTIAL_" + orderId + "_" + uniqueSuffix` |
| **Edge Case** | If cumulative partial refunds equal the full amount, status transitions to `REFUNDED` (effectively a full refund via multiple partials) |

### 6.3 Partial Refund on Already-Partially-Refunded Order

**Trigger:** Second partial refund request on an order already in `PARTIALLY_REFUNDED` status.

| Attribute | Value |
|---|---|
| **Allowed?** | ✅ Yes — `PARTIALLY_REFUNDED` is an eligible status for `processPartialRefund()` |
| **Tracking** | `amountRefunded` accumulates across multiple refunds on both `PaymentIntent` and `Transaction` records |

---

## 7. Delay Approval Flow Refunds

### 7.1 Customer Rejects Delay (AWAITING_DELAY_APPROVAL → CANCELLED_BY_RESTAURANT)

**Trigger:** Restaurant requests extra prep time. Customer receives delay notification and rejects.

| Attribute | Value |
|---|---|
| **State Transition** | `AWAITING_DELAY_APPROVAL` → `CANCELLED_BY_RESTAURANT` |
| **State Handler** | `AwaitingDelayApprovalState.handleDelayRejected()` |
| **Refund Type** | Full refund |
| **Cancellation Reason** | "Customer rejected delay" |

---

### 7.2 Delay Timeout — Customer Unresponsive (AWAITING_DELAY_APPROVAL → CANCELLED_BY_RESTAURANT)

**Trigger:** Customer does not respond to delay approval request within time limit. System auto-rejects.

| Attribute | Value |
|---|---|
| **Mechanism** | `DelayApprovalTimeoutSweeper` publishes `ORDER_DELAY_REJECTED` |
| **State Handler** | `AwaitingDelayApprovalState.handleDelayRejected()` |
| **Refund Type** | Full refund |

---

### 7.3 Restaurant Cancels While Awaiting Delay Approval

**Trigger:** While waiting for customer's delay decision, the restaurant decides to cancel entirely.

| Attribute | Value |
|---|---|
| **State Transition** | `AWAITING_DELAY_APPROVAL` → `CANCELLED_BY_RESTAURANT` |
| **State Handler** | `AwaitingDelayApprovalState.handleOrderCancelledByRestaurant()` |
| **Refund Type** | Full refund |

---

### 7.4 Customer Cancels While Awaiting Delay Approval

**Trigger:** Customer decides to cancel the order while the delay approval modal is active.

| Attribute | Value |
|---|---|
| **State Transition** | `AWAITING_DELAY_APPROVAL` → `CANCELLED` |
| **State Handler** | `AwaitingDelayApprovalState.cancelByCustomer()` |
| **Refund Type** | Full refund |
| **Additional Action** | `emitOrderCancelledByCustomerEvent()` to notify restaurant |

---

### 7.5 Admin Cancels While Awaiting Delay Approval

| Attribute | Value |
|---|---|
| **State Transition** | `AWAITING_DELAY_APPROVAL` → `CANCELLED` |
| **State Handler** | `AwaitingDelayApprovalState.handleOrderCancelledByAdmin()` |
| **Refund Type** | Full refund |

---

## 8. Late Payment on Cancelled Order (Automatic Refund)

### 8.1 Payment Succeeds After Order Already Cancelled (TerminalState)

**Trigger:** Order was cancelled (e.g., stale order sweeper timeout). Payment gateway processes the payment late and fires `PAYMENT_SUCCESS`.

| Attribute | Value |
|---|---|
| **State Handler** | `TerminalState.handlePaymentSuccess()` |
| **Refund Condition** | `if (!"Cancelled by customer".equals(order.getCancellationReason()))` → refund |
| **No Refund If** | Customer explicitly cancelled the order — considered a penalty/customer's fault |
| **Financial Flow** | 1. Record payment ledger entry (Customer → Platform). 2. Immediately issue refund (Platform → Customer). |

**Critical Edge Case:** This is the *only* scenario where `requiresRefund` logic is conditional at the TerminalState level, checking the cancellation reason string.

---

## 9. Refund Failure & Recovery Scenarios

### 9.1 Outbox Event Save Failure (PAYMENT_REFUND_REQUESTED)

**Trigger:** `processRefund()` fails to persist the outbox event (DB down, transaction rolled back).

| Attribute | Value |
|---|---|
| **Handling** | Exception caught, logged: "Failed to enqueue payment refund event for order {}" |
| **Recovery** | Manual intervention required. Order remains in cancelled state but payment not refunded. |
| **Risk** | Customer charged but not refunded. **Requires admin dashboard alert.** |

---

### 9.2 Payment Gateway Refund API Failure

**Trigger:** `IPaymentGatewayStrategy.initiateRefund()` returns `false` or throws exception.

| Attribute | Value |
|---|---|
| **Handling** | `OrderEventConsumer` throws `RuntimeException` → Kafka retry (4 attempts, exponential backoff: 2s, 4s, 8s, max 10s) |
| **DLQ** | After 4 failed attempts, event moves to Dead Letter Topic. `processDeadLetterTopic()` logs error for manual intervention. |
| **PaymentIntent Status** | Remains `REFUND_PENDING` if the refund request was persisted but gateway call failed |

---

### 9.3 REFUND_FAILED Status (Partial Refund Outbox Failure)

**Trigger:** `processPartialRefund()` fails after persisting the outbox event but before the transaction commits.

| Attribute | Value |
|---|---|
| **Handling** | `markRefundFailedWithRetry(intent)` — retries up to 3 times with exponential backoff to mark PaymentIntent as `REFUND_FAILED` |
| **PaymentIntent Status** | `REFUND_FAILED` |
| **Retry-ability** | `REFUND_FAILED` is an **eligible status** for both `processRefund()` and `processPartialRefund()`, allowing admin to re-trigger |

---

### 9.4 Optimistic Lock Failure on REFUND_FAILED Marking

**Trigger:** Concurrent update to PaymentIntent while trying to mark it as `REFUND_FAILED`.

| Attribute | Value |
|---|---|
| **Handling** | Retry loop with `ObjectOptimisticLockingFailureException`, up to `MAX_OPTIMISTIC_LOCK_RETRIES` (3) |
| **Backoff** | Exponential: `2^retry * 100ms` |
| **Exhaustion** | Logs CRITICAL error but does **not** propagate exception (prevents Kafka listener crash) |

---

### 9.5 Webhook Processing Failure for Refund Confirmation

**Trigger:** Payment gateway fires `refund.success` webhook but `handleRefundSuccess()` fails.

| Attribute | Value |
|---|---|
| **Handling** | `RuntimeException` thrown → gateway will retry the webhook |
| **Idempotency** | Webhook event ID checked via `isEventProcessed()` to prevent double-processing |
| **Risk** | If PaymentIntent not found: throws "PaymentIntent not found for gatewayOrderId" |

---

## 10. Refund Idempotency & Duplicate Prevention

### 10.1 Deterministic Transfer IDs

| Refund Type | Transfer ID Formula |
|---|---|
| Full Refund | `UUID.nameUUIDFromBytes(("REFUND_" + orderId).getBytes())` |
| Partial Refund | `UUID.nameUUIDFromBytes(("REFUND_PARTIAL_" + orderId + "_" + uniqueSuffix).getBytes())` |
| Payment (initial) | `UUID.nameUUIDFromBytes(("PAYMENT_" + orderId).getBytes())` |

### 10.2 Duplicate Webhook Protection

- `WebhookProcessingService.isEventProcessed(eventId)` — checks if webhook event was already handled
- Returns `200 OK` immediately for duplicates without re-triggering saga events

### 10.3 Wallet Refund Idempotency

- `WalletService.reverseDebit()` uses `refundRefId = originalReferenceId + "_REFUND"`
- Checks `processedEventRepository.existsById(refundRefId)` before processing
- `GenericWalletEventConsumer` processes `REFUND_GENERATED` events with `referenceId: "REFUND_" + orderId`

---

## 11. Wallet Refund Scenarios

### 11.1 Standard Wallet Refund Credit

**Trigger:** `processRefund()` accepts a `RefundDestination` (WALLET vs GATEWAY) parameter. For WALLET refunds, it emits a `PAYMENT_REFUND_REQUESTED` event with `refundDestination=WALLET`.

| Attribute | Value |
|---|---|
| **Gateway Routing** | `PaymentGatewayIntegration` processes the mock/webhook refund and emits `PAYMENT_REFUNDED` with `refundDestination=WALLET`. |
| **Outbox Relay** | `CustomerApplication` consumes `PAYMENT_REFUNDED`, sees WALLET destination, and emits a `REFUND_GENERATED` outbox event. |
| **Consumer** | `GenericWalletEventConsumer` in WalletService credits the wallet. |
| **Idempotency** | `referenceId` = `"REFUND_" + orderId` → tracked in `ProcessedEvent` table |

### 11.2 Wallet Refund for Ledger-Rejected Transaction

**Trigger:** Ledger service rejects a debit transaction, wallet needs to reverse the debit.

| Attribute | Value |
|---|---|
| **Method** | `WalletService.reverseDebit(walletId, amount, originalReferenceId, reason)` |
| **Idempotency** | `refundRefId = originalReferenceId + "_REFUND"` |
| **Ledger Event** | Does **NOT** publish a ledger event (since the original ledger entry was rejected) |

### 11.3 Wallet Inactive During Refund

**Trigger:** Customer's wallet is frozen or closed when refund is attempted.

| Attribute | Value |
|---|---|
| **Handling** | Throws `WalletInactiveException` |
| **Recovery** | Kafka retries 3 times (1s, 2s, 4s backoff). If still inactive → DLQ for manual resolution. |
| **Risk** | Refund amount lost if wallet remains inactive. Admin must reactivate wallet and re-process. |

---

## 12. Ledger Reversal Scenarios

### 12.1 Standard Refund Ledger Entry

When a `PAYMENT_REFUNDED` event is confirmed:

| Attribute | Value |
|---|---|
| **Direction** | Platform → Customer |
| **Category** | `ChargeCategory.REFUND` |
| **Transfer ID** | `UUID.nameUUIDFromBytes(("REFUND_" + orderId).getBytes())` |
| **Amount** | `order.getTotalAmount()` (full) or `amountRefunded` (partial) |

### 12.2 Partial Refund Ledger Entry

| Attribute | Value |
|---|---|
| **Direction** | Platform → Customer |
| **Category** | `ChargeCategory.REFUND` |
| **Transfer ID** | `UUID.nameUUIDFromBytes(("REFUND_PARTIAL_" + orderId + "_" + suffix).getBytes())` |
| **Amount** | `partialAmount` from event payload |

### 12.3 Charge Reversal for Delivered-Then-Refunded Orders

**Edge Case:** If an order was delivered (ledger entries for food cost, platform fee, delivery fee, etc. already recorded) and then a refund is issued post-delivery:

| Consideration | Detail |
|---|---|
| **Current Behavior** | Only the customer-facing refund ledger entry is created. Individual charge entries (Restaurant earning, Driver earning, Platform fee) are **NOT** reversed. |
| **Implication** | The platform absorbs the loss. Restaurant and Driver earnings are not clawed back. |
| **Future Enhancement** | May need charge-level reversal entries for full accounting accuracy. |

---

## 13. Refund Webhook Processing Scenarios

### 13.1 Full Refund Webhook (refund.success)

**Trigger:** Payment gateway sends `refund.success` webhook after processing refund.

| Step | Action |
|---|---|
| 1 | `VyaparWebhookStrategy` routes to `delegate.handleRefundSuccess()` |
| 2 | `PaymentIntent` fetched with pessimistic lock (`findLockedByGatewayOrderId`) |
| 3 | `amountRefunded` updated: `currentRefund + finalRefundAmount` |
| 4 | Status check: if `amountRefunded >= amount` → `REFUNDED`; else → `PARTIALLY_REFUNDED` |
| 5 | Transaction record updated with refunded amount |
| 6 | `PaymentRefundedEvent` emitted via outbox with appropriate `eventType` |

### 13.2 Partial Refund Webhook

**Same flow as 13.1** but:
- `amountRefunded < amount` → status set to `PARTIALLY_REFUNDED`
- Event type: `PAYMENT_PARTIALLY_REFUNDED`

### 13.3 Refund Webhook with Zero Amount (Fallback)

**Edge Case:** Gateway sends `amount_refunded = 0` but includes `amount` field.

| Attribute | Value |
|---|---|
| **Handling** | Falls back to `amount` field: `if (tempRefund == 0 && rootNode.has("amount"))` |
| **Risk** | If both fields are zero or missing, refund amount defaults to `BigDecimal.ZERO` — no financial movement occurs |

### 13.4 Refund Webhook on Missing PaymentIntent

**Trigger:** Webhook references a `gatewayOrderId` not found in the database.

| Attribute | Value |
|---|---|
| **Handling** | Throws `RuntimeException("PaymentIntent not found for gatewayOrderId: ...")` |
| **Impact** | Transaction rolled back. Gateway will retry webhook. |

---

## 14. Edge Cases & Race Conditions

### 14.1 Double Refund Prevention

**Scenario:** Two concurrent events (e.g., restaurant cancel + admin cancel) both trigger `requiresRefund = true`.

| Attribute | Value |
|---|---|
| **Protection** | `processRefund()` checks PaymentIntent status: only `SUCCESS`, `CAPTURED`, or `REFUND_FAILED` are eligible |
| **If Already Refunded** | Logs: "Cannot refund PaymentIntent {} in status {}" and skips |
| **If REFUND_PENDING** | Not eligible for re-refund — previous refund is already in progress |

### 14.2 Refund on Stale-Swept Order That Later Gets Paid

**Scenario:** 
1. Order `CREATED` for > 15 minutes → `StaleOrderSweeper` cancels it (no refund, payment never succeeded)
2. Payment gateway belatedly processes payment → `PAYMENT_SUCCESS` event
3. `TerminalState.handlePaymentSuccess()` fires

| Attribute | Value |
|---|---|
| **Refund Decision** | Checks `cancellationReason` — if **not** "Cancelled by customer" → refund |
| **Actual Reason** | "Payment timeout after 15 minutes" → **refund IS issued** |

### 14.3 Concurrent Partial Refund + Full Cancellation

**Scenario:** Restaurant issues partial refund for item X while admin simultaneously cancels the entire order.

| Attribute | Value |
|---|---|
| **Risk** | Both `processPartialRefund()` and `processRefund()` may execute |
| **Protection** | `processRefund()` uses `order.getTotalAmount()` and `processPartialRefund()` uses `partialAmount` — the PaymentIntent status gate prevents double-processing since the first to complete moves status to `REFUND_PENDING` |
| **Post-Condition** | One refund succeeds; the other finds status is `REFUND_PENDING` and skips |

### 14.4 Refund Event Consumed Before Saga State Updates

**Scenario:** `PAYMENT_REFUNDED` event arrives at `OrderSagaOrchestrator` while the order DB record hasn't been updated to cancelled yet.

| Attribute | Value |
|---|---|
| **Handling** | Refund event processing is independent of order status — it updates PaymentIntent and records ledger transaction regardless |
| **Protection** | Deterministic transfer IDs prevent double-recording |

### 14.5 Gateway Webhook Arrives Before Outbox Event Published

**Scenario:** Payment gateway fires `refund.success` webhook before `PAYMENT_REFUND_REQUESTED` outbox event is even published by `CustomerApplication`.

| Attribute | Value |
|---|---|
| **Impact** | No direct conflict — webhook processing (`PaymentGatewayIntegration`) and outbox event processing (`OrderEventConsumer`) are independent paths |
| **Edge Case** | `OrderEventConsumer` calls `initiateRefund()` on a gateway that's already processed the refund → gateway returns error/false → Kafka retries → eventually succeeds or DLQ |

### 14.6 Network Partition Between Services During Refund

**Scenario:** Kafka becomes temporarily unavailable after `processRefund()` persists outbox events but before they're polled and published.

| Attribute | Value |
|---|---|
| **Handling** | Outbox pattern ensures events are persisted to DB first. Outbox poller will retry on Kafka availability. |
| **Customer Impact** | Delayed refund processing, but no data loss. |

---

## 15. Scenarios Where NO Refund is Issued

### 15.1 Payment Failed (Never Charged)

| State | Reason | Handler |
|---|---|---|
| `CREATED` → `CANCELLED` | Payment gateway returned failure | `CreatedState.handlePaymentFailure()` |
| | Customer never completed payment | `StaleOrderSweeper.cancelStaleOrder()` |

No money was collected → nothing to refund.

### 15.2 Customer Cancellation After Restaurant Accepts

| State | Reason | Handler |
|---|---|---|
| `ACCEPTED` / `PREPARING` / `READY_FOR_PICKUP` | Customer tries to cancel | Returns error: "Cannot cancel after restaurant accepts" |

Customer cancellation is **blocked** once restaurant has accepted. No refund possible through this path.

### 15.3 Customer-Initiated Cancellation on CREATED Order (Pre-Payment)

| State | Reason | Handler |
|---|---|---|
| `CREATED` → `CANCELLED` | Customer cancels before paying | `CreatedState.cancelByCustomer()` |

No `requiresRefund` is set because payment was never made.

### 15.4 Late Payment on Customer-Cancelled Order

| Condition | `TerminalState.handlePaymentSuccess()` |
|---|---|
| `cancellationReason == "Cancelled by customer"` | **No refund** — customer is at fault |

### 15.5 Successful Delivery

Order delivered successfully → all charges stand. Refund only if post-delivery customer complaint is handled through a separate customer support flow (not currently automated).

### 15.6 Dispatch Failure Alone (Without Admin Cancel)

| State | Detail |
|---|---|
| `DeliveryStatus.FAILED` (dispatch) | `AcceptedState/PreparingState/ReadyForPickupState.handleDispatchFailed()` |
| **Does NOT** set `requiresRefund` | Dispatch failure only updates `DeliveryStatus`; `OrderStatus` remains unchanged |
| **Resolution** | Admin must either manually assign a driver or explicitly cancel (which then triggers refund) |

---

## 16. Payment Intent Status Lifecycle

```
 CREATED(10)
    │
    ▼
 INITIATED(20)
    │
    ▼
 PENDING(30)
    │
    ├─── SUCCESS(40) ───┐
    │                    │
    ▼                    ▼
 FAILED(50)       CAPTURED(60)
                        │
                        ├─── REFUND_PENDING(100)
                        │         │
                        │         ├─── REFUNDED(90) ◄────────┐
                        │         │                           │
                        │         ├─── PARTIALLY_REFUNDED(80)─┤
                        │         │                           │
                        │         └─── REFUND_FAILED(110) ────┘
                        │                    │                 (retry allowed)
                        └────────────────────┘
```

### Refundable Statuses

| Method | Eligible Statuses |
|---|---|
| `processRefund()` | `SUCCESS`, `CAPTURED`, `REFUND_FAILED` |
| `processPartialRefund()` | `SUCCESS`, `CAPTURED`, `PARTIALLY_REFUNDED`, `REFUND_FAILED` |

---

## 17. Refund Amount Calculation Rules

### Full Refund
- Amount: `order.getTotalAmount()` — the full order total including all charges (food, delivery fee, platform fee, taxes, packaging, surge pricing)
- The entire amount paid by the customer is returned

### Partial Refund (Item Unavailable)
- Amount: Proportional food cost + proportional tax for the specific unavailable item(s)
- Delivery fee, platform fee, packaging fee, surge pricing: **NOT refunded** (order is still being delivered)
- The `partialAmount` is explicitly passed by the restaurant API

### Wallet Credit Amount
- For full refund: `order.getTotalAmount()` credited to customer wallet
- For partial: specific `amount` from event payload
- Refund paths are **mutually exclusive** (RefundDestination is either WALLET or GATEWAY, never both).

### Ledger Recording
- Full refund: `Platform → Customer`, `ChargeCategory.REFUND`, `totalAmount`
- Partial refund: `Platform → Customer`, `ChargeCategory.REFUND`, `partialAmount`
- Uses deterministic UUIDs to ensure idempotency across retries

---

## Appendix: Complete Refund Trigger Map

| # | Trigger Event | Source State | State Handler | Refund Type | Amount |
|---|---|---|---|---|---|
| 1 | Restaurant rejects order | `PENDING_ACCEPTANCE` | `PendingAcceptanceState.handleOrderCancelledByRestaurant` | Full | `totalAmount` |
| 2 | Customer cancels before acceptance | `PENDING_ACCEPTANCE` | `PendingAcceptanceState.cancelByCustomer` | Full | `totalAmount` |
| 3 | Admin cancels | `PENDING_ACCEPTANCE` | `PendingAcceptanceState.handleOrderCancelledByAdmin` | Full | `totalAmount` |
| 4 | Restaurant cancels after accepting | `ACCEPTED` | `AcceptedState.handleOrderCancelledByRestaurant` | Full | `totalAmount` |
| 5 | Admin cancels | `ACCEPTED` | `AcceptedState.handleOrderCancelledByAdmin` | Full | `totalAmount` |
| 6 | Restaurant cancels mid-preparation | `PREPARING` | `PreparingState.handleOrderCancelledByRestaurant` | Full | `totalAmount` |
| 7 | Admin cancels | `PREPARING` | `PreparingState.handleOrderCancelledByAdmin` | Full | `totalAmount` |
| 8 | Customer rejects delay | `AWAITING_DELAY_APPROVAL` | `AwaitingDelayApprovalState.handleDelayRejected` | Full | `totalAmount` |
| 9 | Restaurant cancels during delay wait | `AWAITING_DELAY_APPROVAL` | `AwaitingDelayApprovalState.handleOrderCancelledByRestaurant` | Full | `totalAmount` |
| 10 | Customer cancels during delay wait | `AWAITING_DELAY_APPROVAL` | `AwaitingDelayApprovalState.cancelByCustomer` | Full | `totalAmount` |
| 11 | Admin cancels during delay wait | `AWAITING_DELAY_APPROVAL` | `AwaitingDelayApprovalState.handleOrderCancelledByAdmin` | Full | `totalAmount` |
| 12 | Restaurant cancels after food ready | `READY_FOR_PICKUP` | `ReadyForPickupState.handleOrderCancelledByRestaurant` | Full | `totalAmount` |
| 13 | Admin cancels | `READY_FOR_PICKUP` | `ReadyForPickupState.handleOrderCancelledByAdmin` | Full | `totalAmount` |
| 14 | Delivery failed (pre-pickup) | `READY_FOR_PICKUP` | `ReadyForPickupState.handleDeliveryFailed` | Full | `totalAmount` |
| 15 | Delivery failed (post-pickup) | `HANDED_OVER` | `HandedOverState.handleDeliveryFailed` | Full | `totalAmount` |
| 16 | Admin cancels after handover | `HANDED_OVER` | `HandedOverState.handleOrderCancelledByAdmin` | Full | `totalAmount` |
| 17 | Late payment on cancelled order | Terminal | `TerminalState.handlePaymentSuccess` | Conditional | `totalAmount` (only if not customer-cancelled) |
| 18 | Admin cancels on CREATED (paid) | `CREATED` | `CreatedState.handleOrderCancelledByAdmin` | Conditional | `totalAmount` (only if `PaymentIntentStatus.SUCCESS`) |
| 19 | Item unavailable (partial) | Any paid state | `processPartialRefund()` | Partial | Item-specific amount |
| 20 | Delay timeout (auto-reject) | `AWAITING_DELAY_APPROVAL` | `AwaitingDelayApprovalState.handleDelayRejected` (via sweeper) | Full | `totalAmount` |
