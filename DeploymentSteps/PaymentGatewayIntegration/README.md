# PaymentGatewayIntegration Deployment

This document contains instructions, logs, and potential pitfalls when deploying `PaymentGatewayIntegration`.

## Deployment Script
To deploy this individual service to the Oracle VM, run:
```bash
./deploy_payment-service.sh
```

## Lessons Learned & Mistakes to Avoid
*(Future agents: Log any deployment issues, port conflicts, or caching mistakes specific to PaymentGatewayIntegration here.)*

- **Common Mistake**: `CommonLibrary` must be synced and built prior to building `PaymentGatewayIntegration` if you have made changes to DTOs or enums (e.g. `OrderStatus`). This is now handled automatically by the deploy script.
- Ensure that the database migrations are run before starting this service if there are schema changes.
