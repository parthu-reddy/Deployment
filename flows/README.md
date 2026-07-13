# Application Flow Diagrams

This directory contains comprehensive flow diagrams covering every possible scenario of interacting with the La Bouffe Food Delivery application.

## Files

| File | Description |
|------|-------------|
| [01_authentication_flows.md](./flows/01_authentication_flows.md) | Login, OTP, JWT, logout, device management, session restore |
| [02_customer_flows.md](./flows/02_customer_flows.md) | Address management, restaurant discovery, cart, ordering |
| [03_restaurant_onboarding_flows.md](./flows/03_restaurant_onboarding_flows.md) | Brand registration, outlet creation, menu setup |
| [04_restaurant_fulfillment_flows.md](./flows/04_restaurant_fulfillment_flows.md) | Order accept/reject, delay request, ready for pickup |
| [05_delivery_executive_flows.md](./flows/05_delivery_executive_flows.md) | Driver onboarding, availability, order ping, pickup, delivery |
| [06_payment_flows.md](./flows/06_payment_flows.md) | Payment creation, webhook processing, refunds |
| [07_order_lifecycle_e2e.md](./flows/07_order_lifecycle_e2e.md) | Complete end-to-end order state machine across all services |
| [08_api_gateway_flows.md](./flows/08_api_gateway_flows.md) | JWT validation, RBAC, session blacklisting, routing |
| [09_notification_flows.md](./flows/09_notification_flows.md) | Notification dispatch, retry, DLT, provider routing |
| [10_maps_and_logistics_flows.md](./flows/10_maps_and_logistics_flows.md) | Autocomplete, geocoding, dispatch, fleet tracking |
| [11_kafka_event_flows.md](./flows/11_kafka_event_flows.md) | Cross-service event flow through Kafka topics |
| [12_error_and_edge_cases.md](./flows/12_error_and_edge_cases.md) | Rate limiting, optimistic locking, timeouts, failures |
