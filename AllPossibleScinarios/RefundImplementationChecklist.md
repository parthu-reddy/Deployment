# Refund Implementation Checklist — Verification Audit

> **Audit Date**: 2026-08-09
> This checklist systematically verifies every refund scenario against the actual codebase implementation. Each item is marked:
> - ✅ **IMPLEMENTED** — Code exists and works correctly
> - ⚠️ **PARTIALLY IMPLEMENTED** — Code exists but has gaps or limitations
> - ❌ **NOT IMPLEMENTED** — Missing implementation that needs to be built
> - 🔍 **NEEDS REVIEW** — Exists but has a potential issue flagged

---

## Table of Contents

1. [Full Refund Triggers (State Machine)](#1-full-refund-triggers-state-machine)
2. [Partial Refund Scenarios](#2-partial-refund-scenarios)
3. [Automated Sweepers & Timeouts](#3-automated-sweepers--timeouts)
4. [Refund Orchestration (processRefund / processPartialRefund)](#4-refund-orchestration)
5. [Payment Gateway Integration](#5-payment-gateway-integration)
6. [Webhook Processing](#6-webhook-processing)
7. [Wallet Refund Credit](#7-wallet-refund-credit)
8. [Ledger Recording](#8-ledger-recording)
9. [Idempotency & Duplicate Prevention](#9-idempotency--duplicate-prevention)
10. [Failure Recovery & Retry Mechanisms](#10-failure-recovery--retry-mechanisms)
11. [No-Refund Guardrails](#11-no-refund-guardrails)
12. [Race Conditions & Concurrency](#12-race-conditions--concurrency)
13. [Admin Operations](#13-admin-operations)
14. [Customer-Facing Experience](#14-customer-facing-experience)
15. [Testing](#15-testing)
16. [Observability & Monitoring](#16-observability--monitoring)
17. [Financial Integrity](#17-financial-integrity)

---

## 1. Full Refund Triggers (State Machine)

Each state handler that sets `requiresRefund = true` is verified.

### Pre-Preparation Phase

| # | Scenario | State Handler | Status | Evidence |
|---|---|---|---|---|
| 1.1 | Restaurant rejects order (PENDING_ACCEPTANCE → CANCELLED_BY_RESTAURANT) | `PendingAcceptanceState.handleOrderCancelledByRestaurant()` | ✅ IMPLEMENTED | Sets `requiresRefund = true`, transitions to `CANCELLED_BY_RESTAURANT` |
| 1.2 | Customer cancels before acceptance (PENDING_ACCEPTANCE → CANCELLED) | `PendingAcceptanceState.cancelByCustomer()` | ✅ IMPLEMENTED | Sets `requiresRefund = true`, comment confirms "Full refund when customer cancels before restaurant accepts" |
| 1.3 | Admin cancels PENDING_ACCEPTANCE order | `PendingAcceptanceState.handleOrderCancelledByAdmin()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.4 | Admin cancels CREATED order (conditional) | `CreatedState.handleOrderCancelledByAdmin()` | ✅ IMPLEMENTED | Conditionally checks `PaymentIntentStatus.SUCCESS` before setting refund flag |

### During Preparation Phase

| # | Scenario | State Handler | Status | Evidence |
|---|---|---|---|---|
| 1.5 | Restaurant cancels after accepting (ACCEPTED → CANCELLED_BY_RESTAURANT) | `AcceptedState.handleOrderCancelledByRestaurant()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.6 | Admin cancels ACCEPTED order | `AcceptedState.handleOrderCancelledByAdmin()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.7 | Restaurant cancels mid-preparation (PREPARING → CANCELLED_BY_RESTAURANT) | `PreparingState.handleOrderCancelledByRestaurant()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.8 | Admin cancels PREPARING order | `PreparingState.handleOrderCancelledByAdmin()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |

### Post-Preparation / Delivery Phase

| # | Scenario | State Handler | Status | Evidence |
|---|---|---|---|---|
| 1.9 | Restaurant cancels after food ready (READY_FOR_PICKUP → CANCELLED_BY_RESTAURANT) | `ReadyForPickupState.handleOrderCancelledByRestaurant()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.10 | Admin cancels READY_FOR_PICKUP order | `ReadyForPickupState.handleOrderCancelledByAdmin()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.11 | Delivery failed pre-pickup (READY_FOR_PICKUP) | `ReadyForPickupState.handleDeliveryFailed()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.12 | Delivery failed post-pickup (HANDED_OVER) | `HandedOverState.handleDeliveryFailed()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.13 | Admin cancels HANDED_OVER order | `HandedOverState.handleOrderCancelledByAdmin()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |

### Delay Approval Phase

| # | Scenario | State Handler | Status | Evidence |
|---|---|---|---|---|
| 1.14 | Customer rejects delay (AWAITING_DELAY_APPROVAL → CANCELLED_BY_RESTAURANT) | `AwaitingDelayApprovalState.handleDelayRejected()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.15 | Restaurant cancels during delay wait | `AwaitingDelayApprovalState.handleOrderCancelledByRestaurant()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.16 | Customer cancels during delay wait | `AwaitingDelayApprovalState.cancelByCustomer()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |
| 1.17 | Admin cancels during delay wait | `AwaitingDelayApprovalState.handleOrderCancelledByAdmin()` | ✅ IMPLEMENTED | Sets `requiresRefund = true` |

### Terminal State

| # | Scenario | State Handler | Status | Evidence |
|---|---|---|---|---|
| 1.18 | Late payment on cancelled order (conditional refund) | `TerminalState.handlePaymentSuccess()` | ✅ IMPLEMENTED | Records payment ledger first, then checks `cancellationReason != "Cancelled by customer"` before setting `requiresRefund = true` |
| 1.19 | Late payment — customer-cancelled (no refund) | `TerminalState.handlePaymentSuccess()` | ✅ IMPLEMENTED | `"Cancelled by customer".equals(cancellationReason)` → skips refund, logs reason |

---

## 2. Partial Refund Scenarios

| # | Scenario | Implementation | Status | Notes |
|---|---|---|---|---|
| 2.1 | `processPartialRefund()` method exists | `OrderSagaOrchestrator.processPartialRefund()` | ✅ IMPLEMENTED | Accepts `Order` and `BigDecimal partialAmount` |
| 2.2 | Partial refund status eligibility check | Same method | ✅ IMPLEMENTED | Checks `SUCCESS`, `CAPTURED`, `PARTIALLY_REFUNDED`, `REFUND_FAILED` |
| 2.3 | Partial refund emits `PAYMENT_REFUND_REQUESTED` to outbox | Same method | ✅ IMPLEMENTED | Uses `amountInInr = partialAmount` (not total) |
| 2.4 | Partial refund DOES NOT emit `REFUND_GENERATED` (wallet credit) | Same method | ✅ IMPLEMENTED | Correct behavior! `processPartialRefund()` does NOT publish `REFUND_GENERATED` to wallet, because the refund goes to the payment gateway (original payment method). **(Note: The previous assumption that this was a gap was incorrect; refunding to the wallet AND the gateway causes a double-refund).** |
| 2.5 | Restaurant API to trigger partial refund | N/A | ❌ NOT IMPLEMENTED | No REST endpoint found in `CustomerApplication` controllers for restaurant to trigger partial refund. `processPartialRefund()` exists but has no caller via HTTP API. |
| 2.6 | Multiple sequential partial refunds | WebhookProcessingService cumulative logic | ✅ IMPLEMENTED | `intent.setAmountRefunded(currentRefund.add(finalRefundAmount))` — accumulates correctly |
| 2.7 | Partial → Full transition when cumulative equals total | `WebhookProcessingService.handleRefundSuccess()` | ✅ IMPLEMENTED | `if (amountRefunded >= amount) → REFUNDED; else → PARTIALLY_REFUNDED` |
| 2.8 | Partial refund sets `REFUND_FAILED` on outbox save failure | Same method | ✅ IMPLEMENTED | Calls `markRefundFailedWithRetry(intent)` in catch block |

---

## 3. Automated Sweepers & Timeouts

| # | Sweeper | Implementation | Status | Refund? | Notes |
|---|---|---|---|---|---|
| 3.1 | Stale CREATED order sweep (payment timeout) | `StaleOrderSweeper` | ✅ IMPLEMENTED | ❌ No Refund | 15min timeout. Cancels orders still in `CREATED` (no payment succeeded). Correct: no refund needed |
| 3.2 | Restaurant acceptance timeout sweep | `RestaurantTimeoutSweeper` | ✅ IMPLEMENTED | ✅ Yes | 10min timeout. Sets `CANCELLED_BY_RESTAURANT`, calls `processRefund()` directly outside transaction |
| 3.3 | Delay approval timeout sweep (in RestaurantTimeoutSweeper) | `RestaurantTimeoutSweeper.sweepStalePaidOrders()` | ✅ IMPLEMENTED | ✅ Yes | Also sweeps `AWAITING_DELAY_APPROVAL` orders > 10 min |
| 3.4 | Delay approval timeout (saga-level) | `OrderSagaOrchestrator.checkDelayApprovalTimeouts()` | 🔍 NEEDS REVIEW | Publishes `ORDER_DELAY_REJECTED` | **Potential double-processing**: Both `RestaurantTimeoutSweeper` (cancels directly) and `checkDelayApprovalTimeouts` (publishes event) run on the same 10-min threshold. Could trigger two parallel cancel paths for the same order. |
| 3.5 | Abandoned delivery sweep (driver timeout) | `AbandonedDeliverySweeper` | ⚠️ PARTIAL | Emits `DELIVERY_FAILED` | Marks `DeliveryStatus.FAILED` and emits event, which is then consumed by `HandedOverState.handleDeliveryFailed()` to set `requiresRefund = true`. Correct chain but indirect. |
| 3.6 | Refund retry sweep (REFUND_FAILED retries) | `RefundRetrySweeper` | ✅ IMPLEMENTED | ✅ Yes | Every 5min, finds `REFUND_FAILED` intents and calls `processRefund()` |
| 3.7 | All sweepers use Redis distributed locks | All sweepers | ✅ IMPLEMENTED | — | `setIfAbsent` with TTL prevents multi-instance race conditions |

---

## 4. Refund Orchestration

### processRefund()

| # | Check | Status | Evidence |
|---|---|---|---|
| 4.1 | Checks PaymentIntent exists | ✅ IMPLEMENTED | `paymentIntentRepository.findByInternalOrderId()` |
| 4.2 | Status gate: only `SUCCESS`, `CAPTURED`, `REFUND_FAILED` | ✅ IMPLEMENTED | `if (intent.getStatus() == SUCCESS || CAPTURED || REFUND_FAILED)` |
| 4.3 | Sets PaymentIntent to `REFUND_PENDING` | ✅ IMPLEMENTED | `latestOrder.setPaymentStatus(PaymentIntentStatus.REFUND_PENDING)` |
| 4.4 | Publishes `PAYMENT_REFUND_REQUESTED` outbox event | ✅ IMPLEMENTED | Includes `gatewayOrderId`, `amountInInr`, `gatewayName`, `orderId` |
| 4.5 | Publishes `REFUND_GENERATED` outbox event (wallet) | ✅ IMPLEMENTED | Includes `entityId`, `entityType: CUSTOMER`, `amount`, `referenceId: REFUND_{orderId}` |
| 4.6 | Both outbox events saved in same transaction | ✅ IMPLEMENTED | Both inside `transactionTemplate.executeWithoutResult()` |
| 4.7 | Exception handling on outbox save failure | ⚠️ PARTIAL | Catches generic `Exception` and logs, but does NOT mark `REFUND_FAILED`. The PaymentIntent status may remain unchanged (pre-REFUND_PENDING). |
| 4.8 | Uses `order.getTotalAmount()` for full refund amount | ✅ IMPLEMENTED | `payloadMap.put("amountInInr", order.getTotalAmount())` |

### processPartialRefund()

| # | Check | Status | Evidence |
|---|---|---|---|
| 4.9 | Status gate includes `PARTIALLY_REFUNDED` | ✅ IMPLEMENTED | Additional eligible status for partial refunds |
| 4.10 | Uses `partialAmount` (not `totalAmount`) for refund amount | ✅ IMPLEMENTED | `payloadMap.put("amountInInr", partialAmount)` |
| 4.11 | On exception, calls `markRefundFailedWithRetry()` | ✅ IMPLEMENTED | Properly marks `REFUND_FAILED` with optimistic lock retry |
| 4.12 | Does NOT publish `REFUND_GENERATED` wallet event | ✅ IMPLEMENTED | Consistent behavior: Wallet is not credited for refunds; payment returns to original gateway. |

---

## 5. Payment Gateway Integration

| # | Check | Implementation | Status | Notes |
|---|---|---|---|---|
| 5.1 | `OrderEventConsumer` consumes `PAYMENT_REFUND_REQUESTED` | `OrderEventConsumer` | ✅ IMPLEMENTED | Filters by `EventType.PAYMENT_REFUND_REQUESTED` |
| 5.2 | Parses `gatewayOrderId`, `amountInInr`, `gatewayName` from payload | Same consumer | ✅ IMPLEMENTED | Handles nested payload parsing with fallback |
| 5.3 | Validates required fields before refund | Same consumer | ✅ IMPLEMENTED | Checks `gatewayOrderId != null && amountInInr > 0 && gatewayNameStr != null` |
| 5.4 | Calls `orchestrator.initiateRefund()` | Same consumer | ✅ IMPLEMENTED | Delegates to `PaymentGatewayOrchestrator.initiateRefund()` |
| 5.5 | Throws `RuntimeException` on refund failure for Kafka retry | Same consumer | ✅ IMPLEMENTED | `throw new RuntimeException("Refund failed for gatewayOrderId: " + ...)` |
| 5.6 | `@RetryableTopic` with 4 attempts + exponential backoff | Same consumer | ✅ IMPLEMENTED | `attempts = "4", delay = 2000, multiplier = 2.0, maxDelay = 10000` |
| 5.7 | `@DltHandler` for terminal failures | Same consumer | ✅ IMPLEMENTED | `processDeadLetterTopic()` logs error for manual intervention |
| 5.8 | VyaparGatewayStrategy actual HTTP refund call | `VyaparGatewayStrategy.initiateRefund()` | ✅ IMPLEMENTED | Real HTTP call with 10s timeout, returns `response.statusCode() == 200` |
| 5.9 | RazorpayStrategy refund implementation | `RazorpayStrategy.initiateRefund()` | ⚠️ MOCK ONLY | Returns `true` without actual API call — needs real integration |
| 5.10 | CashfreeStrategy refund implementation | `CashfreeStrategy.initiateRefund()` | ⚠️ MOCK ONLY | Returns `true` without actual API call — needs real integration |
| 5.11 | `CircuitBreaker` on refund API call | VyaparGatewayStrategy | ❌ NOT IMPLEMENTED | `initiateRefund()` does NOT have `@CircuitBreaker` (unlike `verifyStatus()` which does). Risk: gateway outage floods retries without circuit breaking |
| 5.12 | Invalid gateway name handling | OrderEventConsumer | ✅ IMPLEMENTED | Catches `IllegalArgumentException` from `PaymentGateway.valueOf()` |

---

## 6. Webhook Processing

| # | Check | Implementation | Status | Notes |
|---|---|---|---|---|
| 6.1 | `handleRefundSuccess()` exists | `WebhookProcessingService.handleRefundSuccess()` | ✅ IMPLEMENTED | Full implementation |
| 6.2 | Pessimistic lock on PaymentIntent | Same method | ✅ IMPLEMENTED | Uses `findLockedByGatewayOrderId()` |
| 6.3 | Cumulative `amountRefunded` tracking | Same method | ✅ IMPLEMENTED | `intent.setAmountRefunded(currentRefund.add(finalRefundAmount))` |
| 6.4 | Correct status determination (REFUNDED vs PARTIALLY_REFUNDED) | Same method | ✅ IMPLEMENTED | Compares `amountRefunded` to `intent.getAmount()` |
| 6.5 | Transaction record updated with refund amount | Same method | ✅ IMPLEMENTED | Finds `SUCCESS` transaction and updates `amountRefunded` |
| 6.6 | `PaymentRefundedEvent` emitted via outbox | Same method | ✅ IMPLEMENTED | Event type dynamically set based on REFUNDED vs PARTIALLY_REFUNDED |
| 6.7 | Zero amount fallback handling | Same method | ✅ IMPLEMENTED | `if (tempRefund == 0 && rootNode.has("amount"))` — falls back to `amount` field |
| 6.8 | Missing PaymentIntent throws RuntimeException | Same method | ✅ IMPLEMENTED | Causes transaction rollback + webhook retry |
| 6.9 | Webhook idempotency check | `WebhookProcessingService.isEventProcessed()` | ✅ IMPLEMENTED | Called in both WebhookController and internal processing |
| 6.10 | Zero refund amount (both fields missing/zero) | Same method | 🔍 NEEDS REVIEW | If both `amount_refunded` and `amount` are 0, `finalRefundAmount = 0`. This adds 0 to `amountRefunded` and saves. No financial movement, but webhook is "consumed" and idempotency prevents reprocessing. **Could mask a gateway bug.** |

---

## 7. Wallet Refund Credit

| # | Check | Implementation | Status | Notes |
|---|---|---|---|---|
| 7.1 | `REFUND_GENERATED` event consumed by WalletService | `GenericWalletEventConsumer` | ❌ DEPRECATED | Removed `REFUND_GENERATED` to avoid double-refunds via payment gateway + wallet. |
| 7.2 | Credits customer wallet via `walletService.credit()` | Same consumer | ❌ DEPRECATED | No longer used for order refunds. |
| 7.3 | Uses `referenceId: REFUND_{orderId}` for idempotency | processRefund() in saga | ❌ DEPRECATED | Refund now strictly handled by gateway. |
| 7.4 | Kafka retry on consumer failure | Same consumer | ❌ DEPRECATED | — |
| 7.5 | DLT handler for terminal wallet failures | Same consumer | ❌ DEPRECATED | — |
| 7.6 | Wallet inactive handling | `WalletService.credit()` | ✅ IMPLEMENTED | Throws `WalletInactiveException` if wallet not `ACTIVE` |
| 7.7 | Compensation for ledger-rejected debits | `WalletService.LedgerFailureConsumer` (`ledger-events-dlq`) | ✅ IMPLEMENTED | Replaces the `reverseDebit()`/`LEDGER_TRANSACTION_REPLY` route, which had no producer and was removed |
| 7.8 | Wallet credit for **partial** refunds | processPartialRefund() | ✅ IMPLEMENTED | Correct: No wallet credit. |

---

## 8. Ledger Recording

| # | Check | Implementation | Status | Notes |
|---|---|---|---|---|
| 8.1 | Full refund ledger entry (Platform → Customer) | Saga PAYMENT_REFUNDED handler | ✅ IMPLEMENTED | `recordLedgerTransaction(refundTransferId, PLATFORM, CUSTOMER, totalAmount, REFUND)` |
| 8.2 | Partial refund ledger entry | Saga PAYMENT_PARTIALLY_REFUNDED handler | ✅ IMPLEMENTED | Uses `partialAmount` from event, unique suffix for transfer ID |
| 8.3 | Full refund deterministic transfer ID | Same handler | ✅ IMPLEMENTED | `UUID.nameUUIDFromBytes(("REFUND_" + orderId).getBytes())` |
| 8.4 | Partial refund unique transfer ID | Same handler | ✅ IMPLEMENTED | `UUID.nameUUIDFromBytes(("REFUND_PARTIAL_" + orderId + "_" + uniqueSuffix).getBytes())` |
| 8.5 | Ledger category is `ChargeCategory.REFUND` | Same handler | ✅ IMPLEMENTED | `ChargeCategory.REFUND` (code 90) |
| 8.6 | Late payment ledger entry before refund | `TerminalState.handlePaymentSuccess()` | ✅ IMPLEMENTED | Records `PAYMENT` (Customer → Platform) first, then sets refund flag |
| 8.7 | Post-delivery refund does NOT reverse restaurant/driver earnings | All refund handlers | 🔍 NEEDS REVIEW | Only customer-facing REFUND ledger entry created. Restaurant earnings, driver payout, platform fee entries are NOT reversed. **Platform absorbs the full loss on post-delivery refunds.** |

---

## 9. Idempotency & Duplicate Prevention

| # | Check | Implementation | Status | Notes |
|---|---|---|---|---|
| 9.1 | Webhook event dedup (`isEventProcessed`) | `WebhookProcessingService.isEventProcessed()` | ✅ IMPLEMENTED | Prevents re-processing of same webhook event ID |
| 9.2 | PaymentIntent status gate prevents double full refund | `processRefund()` | ✅ IMPLEMENTED | After first call sets `REFUND_PENDING`, second call is blocked |
| 9.3 | Deterministic transfer IDs for ledger idempotency | Saga refund handlers | ✅ IMPLEMENTED | UUID5 from `REFUND_` + orderId |
| 9.4 | Wallet `ProcessedEvent` tracking | `WalletService.credit()` | ✅ IMPLEMENTED | Checks `processedEventRepository` before processing |
| 9.5 | Ledger-rejection compensation is idempotent | `WalletService.LedgerFailureConsumer` | ✅ IMPLEMENTED | Keyed on the original `referenceId` in the DLQ payload |
| 9.6 | Concurrent cancel events protection | PaymentIntent status gate | ✅ IMPLEMENTED | Second event finds `REFUND_PENDING` → skips |

---

## 10. Failure Recovery & Retry Mechanisms

| # | Check | Implementation | Status | Notes |
|---|---|---|---|---|
| 10.1 | Gateway refund Kafka retry (PaymentService) | `OrderEventConsumer @RetryableTopic` | ✅ IMPLEMENTED | 4 attempts, 2s/4s/8s/10s backoff |
| 10.2 | Gateway refund DLQ on exhaustion | `OrderEventConsumer @DltHandler` | ✅ IMPLEMENTED | Logs for manual intervention |
| 10.3 | `markRefundFailedWithRetry()` optimistic lock handling | `OrderSagaOrchestrator` | ✅ IMPLEMENTED | 3 retries with `2^retry * 100ms` backoff |
| 10.4 | `RefundRetrySweeper` auto-retries `REFUND_FAILED` | `RefundRetrySweeper` | ✅ IMPLEMENTED | Every 5 min, picks up `REFUND_FAILED` intents, calls `processRefund()` |
| 10.5 | `RefundRetrySweeper` has max retry limit | Same sweeper | ❌ NOT IMPLEMENTED | **No retry counter.** Sweeper will retry REFUND_FAILED intents **indefinitely** every 5 minutes until it succeeds. No cap or escalation to admin after N failures. |
| 10.6 | Wallet consumer Kafka retry | `GenericWalletEventConsumer @RetryableTopic` | ✅ IMPLEMENTED | 3 attempts, 1s/2s/4s backoff |
| 10.7 | Wallet DLQ handler | Same consumer | ✅ IMPLEMENTED | `handleDltWalletEvent()` |
| 10.8 | Admin DLQ retry endpoint (OrderEventConsumer) | `AdminDlqController` | ✅ IMPLEMENTED | `POST /api/v1/internal/admin/orders/dlq/retry` with `{dltTopic, partition, offset}` — reads that DLT record and replays it to its original topic with its own key, value and headers (`DeadLetterReplayer`, 2026-09-25; the old JSON-body retry dropped `eventType` and every typed listener ignored it) |
| 10.9 | Payment service DLQ retry endpoint | N/A | ❌ NOT IMPLEMENTED | No admin endpoint to manually re-trigger failed payment refund events that landed in DLQ |
| 10.10 | Wallet service DLQ retry endpoint | N/A | ❌ NOT IMPLEMENTED | No admin endpoint to manually re-trigger failed wallet refund events |

---

## 11. No-Refund Guardrails

| # | Check | Status | Evidence |
|---|---|---|---|
| 11.1 | CREATED order cancel (no payment) → no refund | ✅ IMPLEMENTED | `CreatedState.cancelByCustomer()` does NOT set `requiresRefund`. `CreatedState.handleOrderCancelledByAdmin()` checks `PaymentIntentStatus.SUCCESS` first |
| 11.2 | Stale order sweep (CREATED → CANCELLED) → no refund | ✅ IMPLEMENTED | `StaleOrderSweeper` cancels without any refund logic |
| 11.3 | Customer cannot cancel after restaurant accepts | ✅ IMPLEMENTED | `OrderState.cancelByCustomer()` default throws `IllegalStateTransitionException`. Only `CreatedState`, `PendingAcceptanceState`, `AwaitingDelayApprovalState` override it. |
| 11.4 | Dispatch failure alone → no refund | ✅ IMPLEMENTED | `handleDispatchFailed()` only changes `DeliveryStatus`, does NOT set `requiresRefund` |
| 11.5 | Late payment on customer-cancelled order → no refund | ✅ IMPLEMENTED | `TerminalState.handlePaymentSuccess()` checks `cancellationReason` string match |
| 11.6 | Payment failure → no refund | ✅ IMPLEMENTED | `CreatedState.handlePaymentFailure()` sets `CANCELLED`, no refund flag |
| 11.7 | Terminal state ignores duplicate cancel events | ✅ IMPLEMENTED | `TerminalState.handleOrderCancelledByRestaurant()` logs warning but doesn't re-process |

---

## 12. Race Conditions & Concurrency

| # | Scenario | Protection | Status | Notes |
|---|---|---|---|---|
| 12.1 | Concurrent cancel events → double refund | PaymentIntent status gate | ✅ PROTECTED | First call moves to `REFUND_PENDING`, second call blocked |
| 12.2 | Concurrent partial + full refund | PaymentIntent status gate | ✅ PROTECTED | First to complete moves status, second finds ineligible |
| 12.3 | Concurrent webhook processing | Pessimistic lock | ✅ PROTECTED | `findLockedByGatewayOrderId()` |
| 12.4 | Concurrent wallet balance updates | Row-level lock | ✅ PROTECTED | `findByEntityIdAndEntityTypeForUpdate()` |
| 12.5 | `RestaurantTimeoutSweeper` + `checkDelayApprovalTimeouts` overlap | Redis lock (partial) | 🔍 NEEDS REVIEW | Both target `AWAITING_DELAY_APPROVAL` orders at 10min. `RestaurantTimeoutSweeper` cancels directly + calls `processRefund()`. `checkDelayApprovalTimeouts` publishes `ORDER_DELAY_REJECTED` event which goes through state machine. Could trigger two cancel attempts on the same order. The state machine's `IllegalStateTransitionException` prevents double processing, but the `RestaurantTimeoutSweeper` bypasses the state machine by calling `processRefund()` directly. |
| 12.6 | Sweeper running on multiple instances | Redis distributed locks | ✅ PROTECTED | All sweepers use `redisTemplate.opsForValue().setIfAbsent()` |
| 12.7 | Webhook arrives before outbox event published | Independent paths | ✅ SAFE | Webhook updates PaymentIntent via `handleRefundSuccess()`, outbox event triggers gateway API. Both are independent — webhook finding "already refunded" by gateway is fine |

---

## 13. Admin Operations

| # | Check | Implementation | Status | Notes |
|---|---|---|---|---|
| 13.1 | Admin cancel endpoint exists | `AdminOrderManualController.cancelOrder()` | ⚠️ RESTRICTED | Only allows cancel for `MANUAL_INTERVENTION_REQUIRED` delivery status. Admin **cannot** cancel orders in other states via this endpoint. |
| 13.2 | Admin cancel publishes `ORDER_CANCELLED_BY_ADMIN` | Same endpoint | ✅ IMPLEMENTED | Published to Kafka `TOPIC_ORDER_EVENTS` |
| 13.3 | Admin manual driver assignment | `AdminOrderManualController.assignDriver()` | ✅ IMPLEMENTED | Publishes `FORCE_ASSIGN_DRIVER` event |
| 13.4 | Admin DLQ event replay | `AdminDlqController.retryDlqEvent()` | ✅ IMPLEMENTED | Replays the DLT record at the given coordinates to the topic named in its `kafka_original-topic` / `kafka_dlt-original-topic` header |
| 13.5 | Admin endpoint to cancel ANY order (non-MANUAL_INTERVENTION) | N/A | ❌ NOT IMPLEMENTED | Current admin cancel is gated by `MANUAL_INTERVENTION_REQUIRED`. No "force cancel" endpoint for orders in `PREPARING`, `ACCEPTED`, etc. The state machine has `handleOrderCancelledByAdmin()` handlers, but no HTTP API to trigger them for arbitrary states. |
| 13.6 | Admin endpoint to manually trigger refund for stuck orders | N/A | ❌ NOT IMPLEMENTED | No endpoint to re-trigger refund for an order where the automated flow failed and the refund sweeper isn't picking it up |
| 13.7 | Admin RBAC protection | All admin endpoints | ✅ IMPLEMENTED | `@PreAuthorize("hasRole('ADMIN')")` on all admin endpoints |

---

## 14. Customer-Facing Experience

| # | Check | Implementation | Status | Notes |
|---|---|---|---|---|
| 14.1 | Customer can see refund status (`paymentStatus` on Order) | Order entity | ✅ IMPLEMENTED | `order.paymentStatus` updated to `REFUND_PENDING` / `REFUNDED` / `PARTIALLY_REFUNDED` |
| 14.2 | Push notification for refund issued | N/A | ❌ NOT IMPLEMENTED | No `NotificationTemplate` for refund. Existing templates: `DRIVER_ON_THE_WAY`, `DELAY_APPROVAL_REQUESTED`, `ORDER_READY_FOR_PICKUP`, `ORDER_CANCELLED_DELAY_TIMEOUT`, `NEW_ORDER_DISPATCH`, `ORDER_ASSIGNED`, `OTP_LOGIN`. **Missing**: `ORDER_REFUNDED`, `ORDER_PARTIALLY_REFUNDED` |
| 14.3 | Customer UI shows refund amount and status | UI components | ❌ NOT IMPLEMENTED | No `refund` or `REFUND` references found in `FoodDeliveryAppUI/src`. Customer cannot see refund information in the app. |
| 14.4 | Customer cancel API exists | `OrderSagaOrchestrator.cancelOrderLocally()` | ✅ IMPLEMENTED | Called via saga, properly handles state-machine check and refund flow |
| 14.5 | Refund timeline/ETA shown to customer | N/A | ❌ NOT IMPLEMENTED | No mechanism to show "refund will arrive in X-Y days" |
| 14.6 | Customer complaint / post-delivery refund request | N/A | ❌ NOT IMPLEMENTED | No customer support flow for requesting refund after delivery (e.g., wrong items, quality issue, missing items) |

---

## 15. Testing

| # | Check | Implementation | Status | Notes |
|---|---|---|---|---|
| 15.1 | `PaymentGatewayOrchestratorTest` refund test | `initiateRefund_ShouldDelegateToStrategy()` | ✅ IMPLEMENTED | Verifies delegation to strategy |
| 15.2 | Webhook refund handling test | N/A | ❌ NOT IMPLEMENTED | No unit test for `handleRefundSuccess()` |
| 15.3 | State machine refund trigger tests | N/A | ❌ NOT IMPLEMENTED | No unit tests verifying that each state handler correctly sets `requiresRefund` |
| 15.4 | `processRefund()` unit test | N/A | ❌ NOT IMPLEMENTED | No unit test for the core refund orchestration method |
| 15.5 | `processPartialRefund()` unit test | N/A | ❌ NOT IMPLEMENTED | No unit test for partial refund |
| 15.6 | `RefundRetrySweeper` test | N/A | ❌ NOT IMPLEMENTED | No test for retry sweeper |
| 15.7 | Wallet refund credit test | N/A | ❌ NOT IMPLEMENTED | No test for `REFUND_GENERATED` event consumption |
| 15.8 | Idempotency test (double refund prevention) | N/A | ❌ NOT IMPLEMENTED | No test verifying that concurrent calls don't double-refund |
| 15.9 | Late payment auto-refund test | N/A | ❌ NOT IMPLEMENTED | No test for `TerminalState.handlePaymentSuccess()` refund path |

---

## 16. Observability & Monitoring

| # | Check | Status | Notes |
|---|---|---|---|
| 16.1 | Refund processing logged | ✅ IMPLEMENTED | `log.info("Processing refund for Order {}")` at all steps |
| 16.2 | Refund failure logged with CRITICAL level | ⚠️ PARTIAL | `markRefundFailedWithRetry()` logs `CRITICAL` only after lock exhaustion. Gateway failure logs at `ERROR` level but without CRITICAL keyword. |
| 16.3 | DLQ events logged | ✅ IMPLEMENTED | Both `OrderEventConsumer` and `GenericWalletEventConsumer` DLQ handlers log |
| 16.4 | Metrics/Dashboard for refund rate | ❌ NOT IMPLEMENTED | No Micrometer counters or Prometheus metrics for refund count, refund amount, refund failure rate |
| 16.5 | Alert on REFUND_FAILED stuck intents | ❌ NOT IMPLEMENTED | `RefundRetrySweeper` retries silently. No alert escalation after N failures |
| 16.6 | Alert on DLQ accumulation | ❌ NOT IMPLEMENTED | No monitoring for growing DLQ size |
| 16.7 | Refund amount mismatch alert (refunded > original) | ❌ NOT IMPLEMENTED | No guard in `handleRefundSuccess()` checking if cumulative refund exceeds original amount |

---

## 17. Financial Integrity

| # | Check | Status | Notes |
|---|---|---|---|
| 17.1 | Refund amount never exceeds original payment | 🔍 NEEDS REVIEW | `handleRefundSuccess()` accumulates `amountRefunded` but never validates `amountRefunded <= intent.getAmount()`. If gateway sends erroneous refund amount, the system could record a refund exceeding the original charge. |
| 17.2 | No hardcoded fallback values for refund amounts | ✅ COMPLIANT | Uses `order.getTotalAmount()` or explicit `partialAmount`. No default fallbacks per user rule. |
| 17.3 | Deterministic transfer IDs prevent double-crediting | ✅ COMPLIANT | UUID5 from orderId ensures same refund produces same ledger transfer ID |
| 17.4 | Fail-fast on missing upstream values | ⚠️ PARTIAL | `processRefund()` uses `.ifPresent()` on PaymentIntent — silently skips if not found. Should arguably throw to surface the issue. |
| 17.5 | Partial refund `amountInInr = 0` guard | ❌ NOT IMPLEMENTED | `processPartialRefund()` does not validate that `partialAmount > 0`. A zero-amount partial refund would proceed through the flow. |
| 17.6 | Refund amount > remaining balance guard | ❌ NOT IMPLEMENTED | No check that `partialAmount <= (originalAmount - alreadyRefunded)`. Could attempt to refund more than what remains. |
| 17.7 | Currency consistency | ✅ IMPLEMENTED | All amounts in INR (`amountInInr`), consistent across services |
| 17.8 | `Order.refundedAmount` tracking | ❌ NOT IMPLEMENTED | The `Order` entity has a `refundedAmount` field, but it is **never updated** when `PAYMENT_REFUNDED` or `PAYMENT_PARTIALLY_REFUNDED` events are processed. |

---

## Summary of Gaps Found

### 🔴 Critical (Financial Risk)

| # | Gap | Location |
|---|---|---|
| **C1** | ~~Partial refund does NOT credit customer wallet~~ **(RESOLVED)** | FIXED: Removed `REFUND_GENERATED` from full refunds too to prevent double-crediting! |
| **C2** | ~~No guard against refund exceeding original payment~~ **(RESOLVED)** | FIXED: `handleRefundSuccess()` now caps the refund to the intent amount. |
| **C3** | ~~No partial refund amount validation (zero or negative)~~ **(RESOLVED)** | FIXED: `processPartialRefund()` now validates `partialAmount > 0`. |
| **C4** | ~~No guard: partial refund > remaining refundable amount~~ **(RESOLVED)** | FIXED: `processPartialRefund()` now caps `partialAmount` to remaining refundable amount. |
| **C5** | ~~`Order.refundedAmount` is never updated~~ **(RESOLVED)** | FIXED: `OrderSagaOrchestrator` handlers now properly update the `refundedAmount`. |

### 🟠 Major (Functionality Gap)

| # | Gap | Location |
|---|---|---|
| **M1** | No REST API for restaurant to trigger partial refund | ✅ IMPLEMENTED: `FulfillmentController.partialRefund()` |
| **M2** | Admin cancel restricted to MANUAL_INTERVENTION_REQUIRED only | ✅ IMPLEMENTED: `AdminOrderManualController.cancelOrder()` updated |
| **M3** | No admin "force cancel" for arbitrary order states | ✅ IMPLEMENTED: `AdminOrderManualController.forceCancelOrder()` |
| **M4** | No admin endpoint to manually trigger refund | ✅ IMPLEMENTED: `AdminOrderManualController.forceRefund()` |
| **M5** | No customer push notification for refund events | ✅ IMPLEMENTED: Added notification triggers for partial refunds to `NotificationTemplateSeeder`. |
| **M6** | ~~No customer UI for refund status display~~ **(RESOLVED)** | FIXED: UI tracking and ETA added in `CustomerOrderHistory.tsx`. |
| **M7** | ~~RefundRetrySweeper has no retry cap — infinite retries~~ **(RESOLVED)** | FIXED: `RefundRetrySweeper` now caps retries at 5. |

### 🟡 Moderate (Robustness/Observability)

| # | Gap | Location |
|---|---|---|
| **R1** | ~~Razorpay & Cashfree refund APIs are mocked~~ **(RESOLVED)** | FIXED: Real integration implemented in Phase 2 |
| **R2** | ~~No `@CircuitBreaker` on `initiateRefund()`~~ **(RESOLVED)** | FIXED: Circuit breaker added to `VyaparGatewayStrategy` |
| **R3** | ~~No refund metrics/dashboard~~ **(RESOLVED)** | FIXED: Added `RefundMetricsConfig`, `refund_alerts.yml`, and `GenericWalletEventConsumer` Micrometer counters |
| **R4** | ~~No DLQ retry endpoint for PaymentService or WalletService~~ **(RESOLVED)** | FIXED: Added `AdminDlqController` to both PaymentService and WalletService |
| **R5** | ~~Potential double-processing between `RestaurantTimeoutSweeper` and `checkDelayApprovalTimeouts`~~ **(RESOLVED)** | FIXED: Overlap removed |
| **R6** | ~~`processRefund()` silently skips if PaymentIntent not found~~ **(RESOLVED)** | FIXED: Now throws Exception |
| **R7** | ~~No customer post-delivery refund request flow~~ **(RESOLVED)** | FIXED: Implemented `PostDeliverySupportModal.tsx` |
| **R8** | ~~No unit tests for ANY refund scenario~~ **(RESOLVED)** | FIXED: Created unit tests including `StateRefundTriggerTest` and `WebhookProcessingServiceTest` |
| **R9** | ~~Post-delivery refund doesn't reverse restaurant/driver earnings~~ **(RESOLVED)** | FIXED: Implemented `faultAttribution` logic in `AdminOrderManualController` |

### 🟢 Low (Nice-to-Have)

| # | Gap | Location |
|---|---|---|
| **L1** | ~~No refund ETA/timeline shown to customer~~ **(RESOLVED)** | FIXED: Added `ETA: 5-7 business days` tracking to `CustomerOrderHistory.tsx` |
| **L2** | ~~`processRefund()` catch block doesn't mark `REFUND_FAILED`~~ **(RESOLVED)** | FIXED: Explicitly marks failed |
| **L3** | ~~Zero amount webhook silently processed~~ **(RESOLVED)** | FIXED: Throws IllegalArgumentException |
