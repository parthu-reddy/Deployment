# RestaurantApplication Deployment

This document contains instructions, logs, and potential pitfalls when deploying `RestaurantApplication`.

## Deployment Script
To deploy this individual service to the Oracle VM, run:
```bash
./deploy_restaurant-service.sh
```

## Lessons Learned & Mistakes to Avoid
*(Future agents: Log any deployment issues, port conflicts, or caching mistakes specific to RestaurantApplication here.)*

- **Common Mistake**: `CommonLibrary` must be synced and built prior to building `RestaurantApplication` if you have made changes to DTOs or enums (e.g. `OrderStatus`). This is now handled automatically by the deploy script.
- Ensure that the database migrations are run before starting this service if there are schema changes.
