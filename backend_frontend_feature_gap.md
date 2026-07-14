# Backend Features Not Yet Available in Frontend

This document outlines the features, API endpoints, and business logic that are fully implemented in the microservices backend but are either mocked, simulated, or completely missing in the React frontend (`FoodDeliveryAppUI`).

## 1. Restaurant Order Fulfillment Lifecycle
**Backend Service:** `RestaurantApplication` (`FulfillmentController`)
**Endpoints:**
*   `POST /api/v1/restaurants/{restaurantId}/fulfillment/orders/{orderId}/accept`
*   `POST /api/v1/restaurants/{restaurantId}/fulfillment/orders/{orderId}/reject`
*   `POST /api/v1/restaurants/{restaurantId}/fulfillment/orders/{orderId}/ready`
*   `POST /api/v1/restaurants/{restaurantId}/fulfillment/orders/{orderId}/cancel`

**Frontend Gap:**
The Restaurant Dashboard (`RestaurantDashboard.tsx`) updates order statuses (like moving a new ticket to "Accepted" or "Cooking") entirely via local React state (`onUpdateOrderStatus`). It does not actually dispatch these API calls to the backend to persist the state change or notify the rest of the system (e.g., dispatching a delivery rider). The "API Playground" in the UI only simulates a `/ready-for-pickup` call for demonstration purposes.

---

## 2. Customer Order Delay Approval
**Backend Service:** `CustomerApplication` (`OrderController`)
**Endpoints:**
*   `POST /api/v1/orders/{orderId}/delay-approval`

**Frontend Gap:**
When a restaurant reports a delay, the backend supports a feature where the customer can explicitly approve or reject the delay (often triggering compensation/credits). The Customer Dashboard (`CustomerDashboard.tsx`) simulates this in its mock API Playground, but there is no actual UI flow, button, or real API integration to trigger this endpoint for active orders.

---

## 3. Customer Delivery Availability Check
**Backend Service:** `CustomerApplication` (`CustomerRestaurantController`)
**Endpoints:**
*   `GET /api/v1/restaurants/{id}/delivery-availability`

**Frontend Gap:**
The Customer Application backend supports querying whether a specific restaurant is capable of dispatching a delivery to a customer's specific lat/lng location. The frontend Customer Dashboard logs a mocked version of this request in its API Playground, but does not actually make the network call to enforce delivery boundaries before allowing an order.

---

## 4. Customer Address Book Retrieval
**Backend Service:** `CustomerApplication` (`CustomerAddressController`)
**Endpoints:**
*   `GET /api/v1/customers/{customerId}/addresses`

**Frontend Gap:**
While the frontend allows users to save a new delivery address (`POST /api/v1/customers/{customerId}/addresses`), it never calls the GET endpoint to retrieve saved addresses. The frontend address selection relies on mocked data rather than fetching the customer's actual address book from the database.

---

## 5. Customer Profile Management
**Backend Service:** `CustomerApplication` (`CustomerProfileController`)
**Endpoints:**
*   `PUT /api/v1/customers/profile`

**Frontend Gap:**
While the frontend allows updating the generic Identity Service profile name (`PUT /api/v1/users/profile/name`), it completely omits the Customer-specific profile updates managed by the `CustomerApplication` (like updating saved delivery preferences or emails attached to the Customer entity).

---

## 6. Delivery Executive Real-Time Routing & Timeouts
**Backend Service:** `DeliveryExecutiveApplication` (`LogisticsController`, `DeliveryExecutiveController`)
**Endpoints:**
*   `GET /api/delivery/route` (Fetches optimized delivery routes)
*   `POST /api/delivery/drivers/{driverId}/orders/{orderId}/timeout` (Handles missed deliveries or unreachable customers)

**Frontend Gap:**
The Delivery Dashboard (`DeliveryDashboard.tsx`) renders a static/mock route on the map for immersive navigation. It does not fetch actual geospatial route data from the backend. Additionally, there is no UI button or flow for a delivery rider to report a "timeout" (e.g., waiting at the door for 10 minutes with no answer).

---

## 7. Customer Live Tracking via Server-Sent Events (SSE)
**Backend Service:** `CustomerApplication` (`CustomerTrackingController`)
**Endpoints:**
*   `GET /api/v1/tracking/stream` (Produces `text/event-stream`)

**Frontend Gap:**
The backend is equipped to push real-time telemetry updates (driver coordinates) to the customer via Server-Sent Events. However, the Customer Dashboard relies on a static or polling map visualization and does not consume the SSE stream for live, smooth map animations.

---

## 8. Identity & Role Management (Admin Console)
**Backend Service:** `IdentityService` (`IdentityServiceClient`, `RoleController`)
**Endpoints:**
*   `GET /api/v1/internal/users/{id}`
*   `GET /api/v1/internal/users/by-role`
*   `POST /api/v1/internal/users/{id}/roles`
*   `DELETE /api/v1/internal/users/{id}/roles/{roleName}`

**Frontend Gap:**
There is no "Admin Portal" in the frontend. The backend supports fetching users, viewing users by their roles (Customer, Restaurant, Courier, Admin), and dynamically granting or revoking privileges. None of this is exposed in the UI.

---

## 9. Global Category Management
**Backend Service:** `RestaurantApplication` (`CategoryController`)
**Endpoints:**
*   `POST /api/v1/categories`

**Frontend Gap:**
While the frontend can fetch the master list of categories (`GET /api/v1/categories`) to assign custom timings to them in `CategoryTimingsTab.tsx`, there is no UI form for a platform admin or restaurant to create *new* global categories. 

---

## 10. Payment Gateway Refunds
**Backend Service:** `PaymentGatewayIntegration` (`PaymentController`)
**Endpoints:**
*   `POST /api/payments/refund`

**Frontend Gap:**
The backend is integrated with payment providers to process refunds. However, neither the Customer Dashboard (for cancelling an order) nor the Restaurant Dashboard (for rejecting an order) triggers this refund endpoint. There is no UI for customer support or admins to manually initiate a refund.

---

## 11. Restaurant Catalog Batch Sync
**Backend Service:** `RestaurantApplication` (`CatalogController`)
**Endpoints:**
*   `GET /api/v1/restaurants/{restaurantId}/menu/batch`

**Frontend Gap:**
This bulk data export endpoint is fully functional on the backend but is not used anywhere in the frontend. It is likely designed for headless Point-of-Sale (POS) system integrations rather than direct UI consumption.

---

## 12. Reverse Gap: Identity Service Logout
**Backend Service:** `IdentityService` (`AuthController`)
**Endpoints:**
*   `POST /api/v1/internal/auth/logout` (Expected by UI but MISSING in Backend)

**Frontend Gap:**
This is a reverse gap. The frontend expects the backend to invalidate active sessions and calls `apiPost('/api/v1/internal/auth/logout')` when a partner attempts to sign out. However, the `AuthController` in the backend `IdentityService` does not have a mapping for `/logout`, resulting in a broken logout feature.
