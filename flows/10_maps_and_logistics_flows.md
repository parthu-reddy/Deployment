# 10. Maps & Logistics Flows

## 10.1 Places Autocomplete

```mermaid
sequenceDiagram
    participant U as User
    participant UI as FoodDeliveryAppUI
    participant GW as API Gateway
    participant CS as CustomerService
    participant MI as MapsIntegration
    participant GM as Google Maps API

    U->>UI: Type address in search box
    UI->>GW: GET /api/places/autocomplete?input={query}
    GW->>CS: Forward (public endpoint)
    CS->>MI: GET /api/places/autocomplete?input={query}
    MI->>GM: Google Places Autocomplete API
    GM-->>MI: [predictions]
    MI-->>CS: [{description, placeId, lat, lng}]
    CS-->>GW: 200
    GW-->>UI: 200
    UI-->>U: Show dropdown with suggestions
```

## 10.2 Reverse Geocode

```mermaid
sequenceDiagram
    participant UI as FoodDeliveryAppUI
    participant MI as MapsIntegration
    participant GM as Google Maps API

    UI->>MI: GET /api/places/reverse-geocode?lat={lat}&lng={lng}
    MI->>GM: Google Geocoding API (latlng → address)
    GM-->>MI: {formatted_address, components}
    MI-->>UI: {address, city, state, zipCode}
```

## 10.3 Forward Geocode

```mermaid
sequenceDiagram
    participant SVC as Service
    participant MI as MapsIntegration
    participant GM as Google Maps API

    SVC->>MI: GET /api/places/geocode?address={address}
    MI->>GM: Google Geocoding API (address → latlng)
    GM-->>MI: {lat, lng}
    MI-->>SVC: {lat, lng}
```

## 10.4 Dispatch — Find Nearest Driver

```mermaid
sequenceDiagram
    participant DS as DeliveryService
    participant MI as MapsIntegration
    participant GM as Google Maps API

    DS->>MI: POST /api/logistics/dispatch {restaurantLat, restaurantLng, deliveryLat, deliveryLng}
    MI->>MI: Query available fleet pool (in-memory/Redis)
    MI->>MI: Calculate distance from each driver to restaurant
    MI->>MI: Filter by max radius (e.g., 5km)
    MI->>MI: Sort by distance ascending
    alt Candidates exist
        MI->>GM: GET route for best candidate → restaurant → customer
        GM-->>MI: {distanceKm, durationMinutes}
        MI-->>DS: {candidateDriverId, estimatedPickupEta, estimatedDeliveryEta}
    else No candidates
        MI-->>DS: 404 "No delivery executives available"
    end
```

## 10.5 Route Calculation

```mermaid
sequenceDiagram
    participant SVC as Service
    participant MI as MapsIntegration
    participant GM as Google Maps API

    SVC->>MI: GET /api/logistics/route?originLat=&originLng=&destLat=&destLng=
    MI->>GM: Google Directions API
    GM-->>MI: {distanceKm, durationMinutes, polyline}
    MI-->>SVC: {route details}
```

## 10.6 Fleet Location Update

```mermaid
sequenceDiagram
    participant DS as DeliveryService
    participant MI as MapsIntegration
    participant RD as Redis

    DS->>MI: POST /api/fleet/location {driverId, lat, lng}
    MI->>RD: GEOADD fleet_locations {lng} {lat} {driverId}
    MI->>RD: SET driver:{driverId}:location {lat, lng, timestamp}
    MI-->>DS: 200 OK
```

## 10.7 Fleet Location Query

```mermaid
sequenceDiagram
    participant SVC as Service
    participant MI as MapsIntegration
    participant RD as Redis

    SVC->>MI: GET /api/fleet/location?driverId={id}
    MI->>RD: GET driver:{id}:location
    RD-->>MI: {lat, lng, lastUpdated}
    MI-->>SVC: 200 {lat, lng, lastUpdated}
```

## 10.8 Find Nearby Drivers

```mermaid
sequenceDiagram
    participant SVC as Service
    participant MI as MapsIntegration
    participant RD as Redis

    SVC->>MI: GET /api/fleet/nearby?lat={lat}&lng={lng}&radiusKm={r}
    MI->>RD: GEORADIUS fleet_locations {lng} {lat} {r} km
    RD-->>MI: [driverIds with distances]
    MI->>MI: Filter only AVAILABLE status drivers
    MI-->>SVC: [{driverId, distanceKm}]
```

## 10.9 Fleet Availability Management

```mermaid
flowchart TD
    A["POST /api/fleet/availability\n{driverId, available, lat, lng}"] --> B{available?}
    B -- true --> C[Add to available fleet pool]
    C --> D["GEOADD fleet_locations\n{lng, lat, driverId}"]
    D --> E[Store location]
    B -- false --> F[Remove from available pool]
    F --> G["ZREM fleet_locations driverId"]

    H["DELETE /api/fleet/driver\n?driverId={id}"] --> I[Remove driver from all fleet data]
    I --> J[Clean up Redis entries]
```

## 10.10 Maps API Key Fetch

```mermaid
sequenceDiagram
    participant UI as FoodDeliveryAppUI
    participant MI as MapsIntegration

    UI->>MI: GET /api/config/maps-key
    MI->>MI: Read from environment: GOOGLE_MAPS_API_KEY
    MI-->>UI: 200 {apiKey}
    UI->>UI: Initialize Google Maps JavaScript SDK
```
