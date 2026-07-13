# 6. Payment Flows

## 6.1 Create Payment Order

```mermaid
sequenceDiagram
    participant CS as CustomerService
    participant GW as API Gateway
    participant PS as PaymentService
    participant PG as Payment Gateway (Razorpay/Cashfree/Vyapar)

    CS->>PS: POST /api/v1/payments/create-order?gateway=razorpay {internalOrderId, amountInInr, customerPhone}
    PS->>PS: PaymentGatewayOrchestrator.createOrder()
    PS->>PS: Select gateway strategy (Razorpay/Cashfree/Vyapar)
    PS->>PG: Create order via gateway SDK/API
    alt Success
        PG-->>PS: {gatewayOrderId}
        PS->>PS: Save PaymentIntent (orderId, gateway, gatewayOrderId, amount)
        PS-->>CS: 200 {gatewayOrderId}
    else Gateway error
        PG-->>PS: Error
        PS-->>CS: 500 "Internal server error"
    end
```

## 6.2 Payment Webhook — Success (Razorpay)

```mermaid
sequenceDiagram
    participant PG as Razorpay
    participant WC as WebhookController
    participant PO as PaymentGatewayOrchestrator
    participant KF as Kafka

    PG->>WC: POST /api/v1/webhooks/razorpay {event, payload}
    WC->>PO: processRazorpayWebhook(body)
    PO->>PO: Verify webhook signature
    PO->>PO: Extract orderId, paymentId, status
    alt Payment captured/successful
        PO->>KF: Publish to payment-events {orderId, gatewayOrderId, status: "CAPTURED"}
    else Payment failed
        PO->>KF: Publish to payment-events {orderId, gatewayOrderId, failureReason}
    end
    PO-->>WC: 200
    WC-->>PG: 200 OK
```

## 6.3 Payment Webhook — Success (Cashfree)

```mermaid
sequenceDiagram
    participant PG as Cashfree
    participant WC as WebhookController
    participant PO as PaymentGatewayOrchestrator
    participant KF as Kafka

    PG->>WC: POST /api/v1/webhooks/cashfree {type, data}
    WC->>PO: processCashfreeWebhook(body)
    PO->>PO: Verify signature
    PO->>PO: Extract orderId, status
    alt Payment successful
        PO->>KF: Publish payment-events {orderId, gatewayOrderId, status}
    else Payment failed
        PO->>KF: Publish payment-events {orderId, failureReason}
    end
    PO-->>WC: 200
    WC-->>PG: 200 OK
```

## 6.4 Payment Webhook — Success (Vyapar)

```mermaid
sequenceDiagram
    participant PG as Vyapar
    participant WC as WebhookController
    participant PO as PaymentGatewayOrchestrator
    participant KF as Kafka

    PG->>WC: POST /api/v1/webhooks/vyapar {body}
    WC->>PO: processVyaparWebhook(body)
    PO->>PO: Parse response, extract status
    alt Payment successful
        PO->>KF: Publish payment-events {orderId, gatewayOrderId, status}
    else Payment failed
        PO->>KF: Publish payment-events {orderId, failureReason}
    end
    PO-->>WC: 200
    WC-->>PG: 200 OK
```

## 6.5 Payment Event Processing (in CustomerService Saga)

```mermaid
sequenceDiagram
    participant KF as Kafka (payment-events)
    participant OS as OrderSagaOrchestrator
    participant DB as Order DB
    participant LE as LedgerService

    KF->>OS: Payment event {orderId, gatewayOrderId, status/failureReason}
    OS->>OS: Find PaymentIntent by gatewayOrderId
    OS->>DB: Find Order by internalOrderId

    alt Payment Success (no failureReason)
        OS->>OS: OrderState.handlePaymentSuccess(context)
        OS->>DB: Update order status → PAID
        OS->>LE: Record double-entry: Customer → Platform (totalAmount)
        OS->>OS: Save ORDER_PAID event to Outbox
        Note over OS: Outbox publishes to Kafka → Restaurant picks up
    else Payment Failure (has failureReason)
        OS->>OS: OrderState.handlePaymentFailure(context)
        OS->>DB: Update order status → CANCELLED
        OS->>OS: Save to Outbox
        Note over OS: No charge, order abandoned
    end
```

## 6.6 Refund Flow

```mermaid
sequenceDiagram
    participant OS as OrderSagaOrchestrator
    participant DB as Order DB
    participant PS as PaymentService
    participant PG as Payment Gateway
    participant LE as LedgerService

    OS->>OS: processRefund(order) triggered by cancellation
    OS->>DB: Find PaymentIntent for order
    alt Intent status is SUCCESS/CAPTURED
        OS->>PS: POST /api/v1/payments/refund?gateway={name} {gatewayOrderId, amountInInr, reason}
        PS->>PG: Initiate refund via gateway API
        alt Refund successful
            PG-->>PS: 200
            PS-->>OS: 200
            OS->>DB: Update PaymentIntent status → REFUNDED
            OS->>LE: Record double-entry: Platform → Customer (totalAmount)
        else Refund failed at gateway
            PG-->>PS: Error
            PS-->>OS: 400/500
            OS->>DB: Update PaymentIntent status → REFUND_FAILED
        end
    else Intent not SUCCESS/CAPTURED
        OS->>OS: Skip refund (no payment to refund)
    end
```

## 6.7 Refund with Optimistic Lock Retry

```mermaid
flowchart TD
    A[Refund API call succeeds at gateway] --> B[Start DB update transaction]
    B --> C[Re-fetch PaymentIntent for latest version]
    C --> D[Set status = REFUNDED]
    D --> E[Save PaymentIntent]
    E --> F{OptimisticLockingFailure?}
    F -- No --> G[Record ledger: Platform → Customer]
    G --> H[Done - REFUNDED]
    F -- Yes --> I{retries < MAX_RETRIES?}
    I -- Yes --> J["Sleep 2^retries * 100ms"]
    J --> B
    I -- No --> K[CRITICAL: Refund succeeded at gateway but DB failed]
    K --> L[Throw exception for manual intervention]
```

## 6.8 Frontend Payment Modal Flow

```mermaid
flowchart TD
    A[Order created with paymentIntent] --> B[Open CustomerPaymentModal]
    B --> C[Show gateway, gatewayOrderId, amount]
    C --> D{Payment gateway type?}
    D -- Razorpay --> E[Initialize Razorpay Checkout widget]
    D -- Cashfree --> F[Redirect to Cashfree hosted page]
    D -- Vyapar --> G[Show UPI/QR code from Vyapar]
    E --> H{User completes payment?}
    F --> H
    G --> H
    H -- Success --> I[Gateway sends webhook to backend]
    I --> J[Payment event processed → Order → PAID]
    H -- Failure --> K[Show payment failure message]
    K --> L{Retry?}
    L -- Yes --> B
    L -- No --> M[Order remains CREATED]
```
