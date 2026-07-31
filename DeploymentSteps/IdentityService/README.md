# IdentityService Deployment

This document contains instructions, logs, and potential pitfalls when deploying `IdentityService`.

## Deployment Script
To deploy this individual service to the Oracle VM, run:
```bash
./deploy_identity-service.sh
```

## Lessons Learned & Mistakes to Avoid
*(Future agents: Log any deployment issues, port conflicts, or caching mistakes specific to IdentityService here.)*

- **Common Mistake**: `CommonLibrary` must be synced and built prior to building `IdentityService` if you have made changes to DTOs or enums (e.g. `OrderStatus`). This is now handled automatically by the deploy script.
- Ensure that the database migrations are run before starting this service if there are schema changes.
