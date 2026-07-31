# ApiGateway Deployment

This document contains instructions, logs, and potential pitfalls when deploying `ApiGateway`.

## Deployment Script
To deploy this individual service to the Oracle VM, run:
```bash
./deploy_api-gateway.sh
```

## Lessons Learned & Mistakes to Avoid
*(Future agents: Log any deployment issues, port conflicts, or caching mistakes specific to ApiGateway here.)*

- **Common Mistake**: `CommonLibrary` must be synced and built prior to building `ApiGateway` if you have made changes to DTOs or enums (e.g. `OrderStatus`). This is now handled automatically by the deploy script.
- Ensure that the database migrations are run before starting this service if there are schema changes.
