# Ride to Trip Migration Notes

## What Changed

- Passenger dashboard now routes to `CreateTripPage` and `TripHistoryPage`.
- Driver dashboard now routes to `IncomingTripRequestPage`, `EarningsPage`, and `DriverTripHistoryPage`.
- Obsolete ride pages were removed from the active source tree:
  - `lib/pages/passenger/book_ride_page.dart`
  - `lib/pages/passenger/passenger_booking_flow_page.dart`
  - `lib/pages/passenger/trips_page.dart`
  - `lib/pages/driver/driver_requests_page.dart`
  - `lib/pages/driver/driver_trips_page.dart`
  - `lib/pages/driver/driver_earnings_page.dart`
- Passenger settings now use `TripPreferencesPage`.

## Backend-Aligned Trip Layer

- `lib/core/api/api_client.dart` normalizes Laravel response envelopes using authenticated bearer-token requests.
- `lib/features/trips/domain/trip_models.dart` models the real lifecycle:
  `REQUESTED`, `MATCHED`, `DRIVER_CONFIRMED`, `DRIVER_ARRIVING`,
  `PICKED_UP`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`, `DISPUTED`.
- `lib/features/trips/data/trip_repository.dart` targets the verified mobile APIs:
  - `POST /api/v1/mobile/trips/request`
  - `GET /api/v1/passenger/trips`
  - `GET /api/v1/mobile/trips/current`
  - `GET /api/v1/mobile/trips/{id}/track`
  - `PUT /api/v1/mobile/trips/{id}/cancel`
  - `POST /api/v1/mobile/drivers/trips/{id}/accept`
  - `POST /api/v1/mobile/drivers/trips/{id}/reject`
  - `PUT /api/v1/mobile/drivers/trips/{id}/start`
  - `PUT /api/v1/mobile/drivers/trips/{id}/complete`
  - `POST /api/v1/mobile/driver/live-location`
  - `POST /api/v1/devices/push-token`

## New Trip Pages

- Passenger:
  - `CreateTripPage`
  - `PublicTransportTripPage`
  - `PrivateTransportTripPage`
  - `MotoTripPage`
  - `TripSearchingPage`
  - `DriverMatchedPage`
  - `DriverArrivingPage`
  - `LiveTripTrackingPage`
  - `TripCompletionPage`
  - `TripHistoryPage`
  - `TripDetailsPage`
  - `EmergencySupportPage`
- Driver:
  - `IncomingTripRequestPage`
  - `DriverNavigationPage`
  - `PickupConfirmationPage`
  - `ActiveTripPage`
  - `DriverTripHistoryPage`
  - `EarningsPage`

## Verification

- `flutter test` passes.
- `flutter analyze` has no new trip-refactor errors. It still reports existing project lint warnings in older files.
