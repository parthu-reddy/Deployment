# Test Users Information

The dummy data generation scripts create a set of users across different roles with specific phone number ranges. When logging into the application or running UI tests, you can use these phone numbers to authenticate as the respective user types.

### Customers (Role: `CUSTOMER`)
- **Phone Numbers:** `6000000001` to `6000000500` (Batch 1)
- **Phone Numbers:** `8000000001` to `8000000500` (Batch 2)
- *These accounts have customer profiles and saved addresses.*

### Delivery Executives/Riders (Role: `DELIVERY`)
- **Phone Numbers:** `5000000001` to `5000000030`
- *These accounts are registered as delivery executives with assigned vehicles.*

### Restaurant Owners (Role: `RESTAURANT`)
- **Phone Numbers:** `9000000001` to `9000000010`
- *These accounts are linked to the generated dummy brands and outlets.*
