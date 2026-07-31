# ConfigService Deployment

This document contains instructions, logs, and potential pitfalls when deploying `ConfigService`.

## Deployment Script
To deploy this individual service to the Oracle VM, run:
```bash
./deploy_config-service.sh
```

## Lessons Learned & Mistakes to Avoid
*(Future agents: Log any deployment issues, port conflicts, or caching mistakes specific to ConfigService here.)*

- **Common Mistake**: `CommonLibrary` must be synced and built prior to building `ConfigService` if you have made changes to DTOs or enums (e.g. `OrderStatus`). This is now handled automatically by the deploy script.
- Ensure that the database migrations are run before starting this service if there are schema changes.
