# Delivery Executive (Rider) Scenarios

This document outlines all the scenarios implemented in the Food Delivery application for the Delivery Executive (Rider).

## 1. Availability Management
### Scenario: Going Online
* **Trigger:** Rider toggles their status to "Online" on the Delivery Dashboard.
* **Action:** The system updates the driver's status to `ONLINE` in the database.
* **Result:** The driver's ID is added to the `drivers:available:{cityId}` Redis set. They become eligible to receive new order dispatches.

### Scenario: Going Offline
* **Trigger:** Rider toggles their status to "Offline".
* **Action:** The system updates the driver's status to `OFFLINE`.
* **Result:** The driver is removed from the `drivers:available:{cityId}` Redis set and will no longer receive pings.

## 2. Order Dispatch & Ping Scenarios
### Scenario: Receiving an Order Ping
* **Trigger:** A customer places an order, or a previous driver rejects an order.
* **Action:** 
  * The `LogisticsDispatchService` queries the `MapsIntegration` service to find the nearest available online driver.
  * An atomic assignment lock (`driver:lock:<id>`) is created in Redis for 30 seconds.
  * A ping notification is sent to the rider via WebSocket (or detected via the 5-second polling fallback).
* **Result:** The rider sees an incoming order ping modal with a countdown timer.

### Scenario: Accepting an Order
* **Trigger:** The rider clicks "Accept" on the incoming order ping modal.
* **Action:**
  * The backend verifies the driver lock.
  * The driver lock (`order:driver:lock:<orderId>`) is created for 60 minutes to prevent other drivers from claiming it.
  * The driver's status is changed to `ON_DELIVERY`.
  * The order status is updated to reflect that a driver has been assigned.
* **Result:** The ping modal closes, and the dashboard transitions to the active delivery view showing the restaurant details.

### Scenario: Rejecting an Order
* **Trigger:** The rider clicks "Reject" on the incoming order ping modal.
* **Action:**
  * The `DeliveryService` triggers the `rejectOrderPing` method.
  * The atomic assignment lock for this driver is released in the Maps service via `/fleet/release`.
  * The driver's ID is added to the `order:rejected_drivers:<orderId>` Redis set (2-hour TTL).
  * An `ORDER_DRIVER_REJECTED` event is published.
* **Result:** The order is removed from the rider's screen. The dispatcher selects the next nearest available driver, explicitly passing the `rejected_drivers` list to avoid pinging the same rider again.

### Scenario: Ping Timeout (No Response)
* **Trigger:** The rider does not click Accept or Reject before the 30-second timer expires.
* **Action:**
  * The `DriverPingTimeoutPoller` (which runs every 5 seconds) detects the expired ping via the `order:ping:timeouts` Redis sorted set.
  * The timeout logic triggers, clearing the driver's pending ping.
  * The atomic assignment lock is released.
  * The driver's ID is added to the `order:rejected_drivers:<orderId>` Redis set (with a 2-hour TTL).
  * An `ORDER_DRIVER_REJECTED` event is published.
* **Result:** The modal closes automatically on the rider's UI. The system re-dispatches the order to the next available driver, and the timed-out driver is excluded from receiving this order again.

### Scenario: Rider Disconnects but Order is Already Assigned (Phantom Modal)
* **Trigger:** An order is dispatched, but the customer or restaurant cancels the order while the ping is on the rider's screen.
* **Action:** 
  * The `TerminalStateStrategy` intercepts the `ORDER_CANCELLED` event, clears the dispatch payload, and forcefully sets the `order:driver:lock` to `CANCELLED` (24h TTL).
  * This completely prevents the rider from successfully accepting an in-flight, orphaned ping.
* **Result:** If the rider presses "Accept", the backend will reject it because the lock is set to `CANCELLED`. The frontend will show "Failed to accept job" and the ping will disappear.

### Scenario: Delayed / Scheduled Dispatch
* **Trigger:** The restaurant marks the order as accepted, but the `estimatedCompletionTime` is far in the future.
* **Action:** The system places the order in a Redis `delayed_dispatch_queue` rather than dispatching it immediately.
* **Result:** The `DelayedDispatchPoller` continuously checks this queue (every 5 seconds) and only triggers the nearest driver search 15 minutes before the `estimatedCompletionTime`.

## 3. Order Fulfillment Scenarios
### Scenario: Arriving at Restaurant
* **Trigger:** The rider arrives at the restaurant.
* **Action:** On the UI, there is currently no separate backend state for "Arrived at Restaurant." The order remains in the `DISPATCHED` state until the food is picked up.

### Scenario: Picking Up the Order
* **Trigger:** The rider collects the food from the restaurant and enters the Pickup OTP in the UI.
* **Action:** The backend verifies the Pickup OTP against the `order:dispatchPayload`.
* **Result:** If the OTP is correct, the order's state transitions to `OUT_FOR_DELIVERY`. The customer is notified that their food is on the way. The driver remains in the `ON_DELIVERY` state.

### Scenario: Delivering the Order
* **Trigger:** The rider reaches the customer and enters the Delivery OTP in the UI.
* **Action:** The backend verifies the Delivery OTP.
* **Result:** If correct, the order's state transitions to `DELIVERED`. The rider's state is automatically switched back to `ONLINE`, and they are re-added to the available driver pool in Redis (`drivers:available:{cityId}`).

## 4. Aborting Deliveries
### Scenario: Driver Aborts an Assigned Order
* **Trigger:** The rider encounters an issue (e.g., flat tire) and aborts the assigned order via the `/api/delivery/drivers/{driverId}/orders/{orderId}/abort` endpoint. (Note: Currently implemented in the backend API, but waiting for a UI button in the Delivery Dashboard).
* **Action:**
  * The `DeliveryService` verifies the lock and clears the `order:driver:lock:<orderId>`.
  * The driver's status is forcefully reset to `ONLINE`, and they are returned to the `drivers:available` Redis pool.
  * An `ORDER_DRIVER_REJECTED` event is sent via the Outbox to trigger re-dispatching.
* **Result:** The rider is removed from the active delivery. The dispatcher searches for a new driver to handle the abandoned order.

## 5. Technical Network Edge Cases
### Scenario: Disconnected WebSockets (Local Dev)
* **Trigger:** The rider's WebSocket connection drops during local development.
* **Action:** The `DeliveryDashboard.tsx` employs a fallback polling mechanism.
* **Result:** The UI falls back to polling the `/api/v1/delivery/drivers/${riderId}/pings` endpoint every 5 seconds. If a ping is detected, the UI instantly calculates the remaining time from the `expiresAt` timestamp and displays the modal, ensuring no pings are missed due to a dropped socket.

### Scenario: Network Disconnect / Inactive Rider (Background Sweeping)
* **Trigger:** The rider's device loses network connectivity, or they close the app without going offline, resulting in no location updates for 60 seconds.
* **Action:** 
  * The frontend stops sending location pings to the WebSocket/API.
  * The `StaleDriverSweeperDaemon` (running every 60s) checks the `driver_last_ping` Redis sorted set.
* **Result:** If a driver hasn't pinged in over 60 seconds, the backend automatically transitions their status to `OFFLINE` and removes them from the `drivers:available` Redis pool. This ensures that disconnected drivers are not assigned new orders.

## 6. Admin & System Overrides
### Scenario: Admin Force Assignment
* **Trigger:** The dispatcher or admin manually overrides the algorithm and assigns a specific driver to an order via the `/api/v1/internal/admin/delivery/orders/{orderId}/assign` endpoint.
* **Action:** The `AdminDeliveryController` bypasses the ping mechanism entirely. It clears any pending pings, forcefully locks the driver to the order, changes the driver's state to `ON_DELIVERY`, and emits a `DRIVER_ASSIGNED` event.
* **Result:** The driver immediately receives the assigned job on their dashboard without needing to accept or reject a ping.

### Scenario: Order Cancelled by Customer / Restaurant While Driver Assigned
* **Trigger:** The customer or restaurant cancels the order after the driver has accepted it, but before delivery is complete.
* **Action:** 
  * The `TerminalStateStrategy` intercepts the `ORDER_CANCELLED` event.
  * It deletes the `order:dispatch:lock` and `order:dispatchPayload`.
  * It releases the driver's global lock (`driver:lock:<id>`) and resets the driver's status to `ONLINE` in the database.
* **Result:** The order disappears from the driver's dashboard, and the driver immediately becomes available for new dispatches without manual intervention.

## 7. Proposed Improvements & Future Features (Checklist)
Based on a thorough end-to-end analysis of the current delivery flow, the following features are recommended to handle real-world operational edge cases and improve rider/customer experience:

- [ ] **1. Expose "Abort Delivery" in the Rider UI (Vehicle Breakdown / Emergency)**
  - *Context:* The backend already supports a `POST /abort` endpoint to cancel an active assignment and re-dispatch it.
  - *Action:* Add a "Report Issue" button on the `DeliveryDashboard.tsx` for active jobs, allowing the rider to drop the order if they have a flat tire or accident.
- [ ] **2. "Arrived at Restaurant" State Tracking**
  - *Context:* Currently, the order remains `DISPATCHED` until the rider picks up the food. If there's a long wait at the restaurant, the customer lacks visibility.
  - *Action:* Add an `AT_RESTAURANT` state to `OrderStatus`. Update the UI's `handleArrivedAtRestaurant` to hit a backend endpoint. Customer UI updates to "Rider is waiting for your food."
- [ ] **3. "Customer Unavailable / Delivery Failed" Flow**
  - *Context:* If the customer doesn't answer the door and the rider cannot get the Delivery OTP, there is no way for the rider to close out the order.
  - *Action:* Add a `DELIVERY_FAILED` flow. Implement a 5-minute wait timer on the UI when the rider arrives at the drop-off location. If the timer expires, expose a "Customer Unavailable" button that triggers the terminal state without an OTP.
- [ ] **4. "Go Offline After Delivery" Intent Toggle**
  - *Context:* Riders currently get auto-switched to `ONLINE` and thrown back into the dispatch pool the millisecond they deliver an order. If they want to end their shift, they risk getting pinged instantly.
  - *Action:* Add a toggle in the UI: "Go offline after this delivery". Send this intent to the backend. The `DeliveredStateStrategy` should respect this flag and set the rider to `OFFLINE` instead of `ONLINE` upon completion.
- [ ] **5. Stacked / Batched Orders (Multi-Dispatch)**
  - *Context:* Riders currently handle one order at a time (`ON_DELIVERY` blocks new pings).
  - *Action:* Allow the `LogisticsDispatchService` to dispatch a second order to a driver if the second order is from the same restaurant and the drop-off is on the way. Modify the UI to handle an array of active jobs instead of just one `currentJob`.
