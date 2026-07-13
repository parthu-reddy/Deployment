# 9. Notification Flows

## 9.1 Notification Dispatch Pipeline

```mermaid
sequenceDiagram
    participant SVC as Any Service (via Outbox)
    participant KF as Kafka
    participant NC as NotificationEventConsumer
    participant NDS as NotificationDispatchService
    participant TP as TemplateResolver
    participant RD as Redis (Rate Limiter)
    participant PR as Provider (SMS/Email/Push)
    participant AU as Audit Log DB

    SVC->>KF: Publish to platform.notifications.dispatch
    KF->>NC: Consume NotificationRequestEvent
    NC->>NDS: routeAndDispatch(event)
    NDS->>TP: Resolve template by eventName
    TP-->>NDS: Template with {params} replaced
    NDS->>RD: Check rate limit for user + channel
    alt Rate limit exceeded
        NDS->>AU: Log RATE_LIMITED
        NDS-->>NC: Return (no send)
    else Within limit
        NDS->>NDS: Resolve recipient address
        NDS->>PR: Send notification
        alt Send succeeds
            PR-->>NDS: 200
            NDS->>AU: Log DELIVERED
        else Send fails (retryable)
            PR-->>NDS: Error
            NDS-->>NC: Throw exception (triggers Kafka retry)
        else Send fails (terminal)
            PR-->>NDS: Terminal error
            NDS-->>NC: Throw TerminalNotificationException
            Note over NC: DLT handler invoked
        end
    end
```

## 9.2 Kafka Retry + Dead Letter Topic

```mermaid
flowchart TD
    A[Notification event consumed] --> B{Process succeeds?}
    B -- Yes --> C[Audit: DELIVERED]
    B -- No (retryable) --> D[Retry #1 after 2s]
    D --> E{Retry succeeds?}
    E -- Yes --> C
    E -- No --> F[Retry #2 after 4s]
    F --> G{Retry succeeds?}
    G -- Yes --> C
    G -- No --> H[Retry #3 after 8s]
    H --> I{Retry succeeds?}
    I -- Yes --> C
    I -- No --> J[Move to Dead Letter Topic]
    J --> K[DltHandler processes]
    K --> L[Audit: FAILED with error reason]
    L --> M[Manual intervention required]

    B -- No (terminal) --> N["TerminalNotificationException (non-retryable)"]
    N --> J
```

## 9.3 SMS Notification Flow (Exotel)

```mermaid
sequenceDiagram
    participant NDS as NotificationDispatchService
    participant EX as ExotelProvider
    participant API as Exotel API
    participant WC as ProviderWebhookController

    NDS->>EX: send(recipientPhone, message)
    EX->>API: POST /Accounts/{sid}/Sms/send {From, To, Body}
    alt API returns 200
        API-->>EX: {SmsSid, Status: "queued"}
        EX-->>NDS: Success
    else API error
        API-->>EX: Error
        EX-->>NDS: Throw exception
    end

    Note over API,WC: Async status callback
    API->>WC: POST /api/v1/webhooks/exotel/status {SmsSid, Status}
    WC->>WC: Log delivery status update
    WC-->>API: 200 OK
```

## 9.4 Notification Event Types

```mermaid
flowchart TD
    A[Notification Events] --> B["DRIVER_ON_THE_WAY\n(Customer)"]
    A --> C["DELAY_APPROVAL_REQUESTED\n(Customer)"]
    A --> D["ORDER_READY_FOR_PICKUP\n(Customer)"]
    A --> E["ORDER_CANCELLED_DELAY_TIMEOUT\n(Customer)"]
    A --> F["OTP Login\n(SMS to phone)"]
```

## 9.5 Notification Channel Routing

```mermaid
flowchart TD
    A[NotificationRequestEvent] --> B{Channel type?}
    B -- SMS --> C[SMS Provider Router]
    C --> D{Active provider?}
    D -- Exotel --> E[ExotelProvider.send]
    D -- Twilio --> F[TwilioProvider.send]
    B -- PUSH --> G[Push Notification Router]
    G --> H[FCM / APNs]
    B -- EMAIL --> I[Email Provider Router]
    I --> J[SMTP / SendGrid / SES]
```
