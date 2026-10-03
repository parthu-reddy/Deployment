# Test Users Information

The dummy data generation scripts create a set of users across different roles with specific phone number formats. Please follow these number formats exclusively for testing, as they correlate with the fully configured accounts (including verified government IDs, addresses, and vehicles).

### Customers (Role: `CUSTOMER`)
- **Phone Numbers:** `8000000001` to `8000000500`
- *These accounts have customer profiles and saved addresses.*

### Delivery Executives/Riders (Role: `DELIVERY`)
- **Phone Numbers:** `7000000001` to `7000000030`
- *These accounts are fully registered as delivery executives with assigned vehicles, approved government IDs, and completed biometric verification.*

### Restaurant Owners (Role: `RESTAURANT`)
- **Phone Numbers:** `9000000001` to `9000000010`
- *These accounts are linked to the generated dummy brands and outlets.*

## O2 organisation ownership — 2026-10-03

All 9000000001–9000000014 restaurant accounts have one ACTIVE OWNER membership in an ACTIVE organisation. The first ten organisation names match Brand 1–10; the four scenarios use their scenario names. 9000000011 owns an organisation with no brand. Seeded brands reference organisations rather than user IDs. The normal Dev browser allowlist and parked E2E runner allowlist are unchanged.

| Brand | Organisation ID | OWNER user ID |
|---|---|---|
| Brand 1 | 6bda9207-420f-53f6-8643-30dc731bff77 | 426f016b-c98e-43c1-b464-94e1a587f6d3 |
| Brand 2 | 7b29e706-f65d-5639-b2e5-9a44c8bce1ba | aa923368-e7d6-49e2-88bf-52bff6ade67e |
| Brand 3 | 5569f66f-b699-55e2-a9cc-3a1786e3f260 | 4f0cce5b-8317-4189-8906-9f05369c4ee9 |
| Brand 4 | d2113ec6-d766-55a1-a14d-f190c17fd38f | 1111c5f9-c69b-4f44-81ee-0e27f4bad2e2 |
| Brand 5 | 2a02a7db-1892-501d-8372-17fd93b92b79 | e01886c2-2819-4338-9b74-46fffeb71f26 |
| Brand 6 | 865f3897-b70a-5da4-a3f6-4ad1c4055481 | 35095146-05f5-4e30-8cc5-75b13ba4da7a |
| Brand 7 | 47f11dc0-b58e-5588-9834-d9928a9ce606 | d828a8c6-ea39-4689-8145-7249940a6645 |
| Brand 8 | 32126a62-c256-541d-9737-a124b90e639a | 629a09b9-c38a-4ca0-80fc-af80f1314972 |
| Brand 9 | ac793bc2-8dd1-56cd-a2d5-daf1012f1d91 | 24cce6fa-e8cb-423a-8740-4061489ab7bd |
| Brand 10 | 42174a67-2f90-515c-9b41-32409a80e990 | c6c75d95-2fb6-4e84-88e8-bb00573188b2 |
