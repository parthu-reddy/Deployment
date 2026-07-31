# FoodDeliveryAppUI Deployment

This document contains instructions, logs, and potential pitfalls when deploying `FoodDeliveryAppUI`.

## Deployment Script
To deploy this individual service to the Oracle VM, run:
```bash
./deploy_food-delivery-app-ui.sh
```

## Lessons Learned & Mistakes to Avoid
*(Future agents: Log any deployment issues, port conflicts, or caching mistakes specific to FoodDeliveryAppUI here.)*

- **Example**: Ensure that the database migrations are run before starting this service if there are schema changes.
