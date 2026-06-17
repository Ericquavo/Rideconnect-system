# Phase 3: Passenger App Implementation Roadmap

**Estimated Duration:** 6-8 hours
**Status:** Ready to Begin
**Dependencies:** Phase 1 & 2 COMPLETE ✅

---

## Phase 3 Overview

Implement the complete passenger trip booking and tracking flow, integrating with the verified backend API.

---

## Phase 3 Tasks (In Order)

### Task 3.1: Passenger Dashboard Screen
**File:** `lib/pages/passenger/passenger_dashboard.dart` (update existing)

**Features to implement:**
1. ✅ Display user profile (name, phone, email)
2. ✅ Quick action buttons:
   - Ride now (motorcycle/private car)
   - Schedule trip (future)
   - My trips history
   - Wallet/Payments
3. ✅ Current active trip indicator
4. ✅ Recent trips list
5. ✅ FAQs & Support

**API Calls:**
- GET `/api/v1/mobile/trips` (list recent trips)
- GET `/api/v1/passenger/profile` (if needed)

**Riverpod Providers Needed:**
- `activeTripsProvider` (watch for active trips)
- `recentTripsProvider` (fetch last 5 trips)

---

### Task 3.2: Pickup Location Selection
**New File:** `lib/features/trips/presentation/pages/pickup_location_page.dart`

**Features:**
1. ✅ Google Maps integration
2. ✅ Current location button
3. ✅ Search for address
4. ✅ Recent locations
5. ✅ Confirm selection button

**Outputs:**
- Latitude, Longitude, Address

**Riverpod Providers:**
- `locationProvider` (current location)
- `addressProvider` (reverse geocoding)

---

### Task 3.3: Destination Location Selection
**New File:** `lib/features/trips/presentation/pages/destination_location_page.dart`

**Features:**
1. ✅ Similar to pickup location
2. ✅ Search suggestions (Google Places)
3. ✅ Favorites/History
4. ✅ Map preview

**Outputs:**
- Latitude, Longitude, Address

---

### Task 3.4: Route Calculation & Pricing
**New File:** `lib/features/trips/presentation/pages/route_summary_page.dart`

**Features:**
1. ✅ Call route compute API
2. ✅ Display:
   - Map with route polyline
   - Distance (km)
   - Estimated time (minutes)
   - Estimated fare
3. ✅ Transport type selection (if not already chosen)
4. ✅ Confirm booking button

**API Calls:**
- POST `/api/v1/route/compute`
  ```json
  {
    "origin_lat": 9.0765,
    "origin_lng": 7.3986,
    "destination_lat": 9.0820,
    "destination_lng": 7.4000,
    "transport_type": "PRIVATE_CAR" // or "MOTORCYCLE"
  }
  ```

**Riverpod Providers:**
- `routeComputeProvider` (async compute)
- `fareEstimateProvider` (derived from route)

---

### Task 3.5: Trip Creation
**New File:** `lib/features/trips/presentation/pages/create_trip_page.dart`

**Features:**
1. ✅ Call trip creation API
2. ✅ Show loading state
3. ✅ Handle errors with dialog
4. ✅ Navigate to matching screen on success

**API Call:**
- POST `/api/v1/mobile/trips`
  ```json
  {
    "origin_lat": 9.0765,
    "origin_lng": 7.3986,
    "origin_address": "Ikoyi, Lagos",
    "destination_lat": 9.0820,
    "destination_lng": 7.4000,
    "destination_address": "Victoria Island, Lagos",
    "transport_type": "PRIVATE_CAR",
    "estimated_fare": 2500,
    "passenger_id": 42
  }
  ```

**Response:**
```json
{
  "success": true,
  "data": {
    "trip_id": 1234,
    "status": "PENDING_DRIVER",
    "created_at": "2026-06-16T10:30:00Z"
  }
}
```

**Riverpod Provider:**
- `createTripProvider` (AsyncValue with trip data)

---

### Task 3.6: Driver Matching Screen
**File:** `lib/screens/passenger/driver_matching_screen.dart` (update)

**Features:**
1. ✅ Subscribe to RTDB: `active_trips/{trip_id}` status changes
2. ✅ Show:
   - Search animation
   - "Looking for drivers..."
   - Candidate count (from polling or RTDB)
   - Cancel button (calls cancel API)
3. ✅ On driver assigned:
   - Show driver card (name, rating, vehicle)
   - Navigate to tracking screen

**RTDB Listen:**
```dart
Stream<TripRealtimeEvent> tripStatus = 
  TripRealtimeService.watchTrip(tripId);
```

**Events to handle:**
- `DRIVER_ASSIGNED`
- `DRIVER_ACCEPTED`
- `CANCELLED` (by driver)

**Riverpod Providers:**
- `tripStatusStreamProvider` (family, by tripId)
- `tripCandidatesProvider` (polling or calculated)

---

### Task 3.7: Trip Tracking Screen
**File:** `lib/screens/passenger/trip_tracking_screen.dart` (update)

**Features:**
1. ✅ Real-time driver location updates (RTDB)
2. ✅ Map with:
   - Driver marker (live)
   - Pickup marker
   - Destination marker
   - Route polyline
3. ✅ Trip status display
4. ✅ Driver info card
5. ✅ Call/Message driver buttons
6. ✅ Emergency alert button

**RTDB Listens:**
```dart
// Driver location updates
Stream<Map> driverLocation = 
  RTDBService.getDriverLocationStream(driverId);

// Trip status updates
Stream<Map> tripStatus = 
  RTDBService.getTripStatusStream(tripId);
```

**Events to handle:**
- `DRIVER_ARRIVED_AT_PICKUP`
- `TRIP_STARTED`
- `TRIP_COMPLETED`
- Emergency alerts

---

### Task 3.8: Trip Completion & Rating
**New File:** `lib/features/trips/presentation/pages/trip_completion_page.dart`

**Features:**
1. ✅ Show trip summary:
   - Distance, time, fare
   - Payment method & status
2. ✅ Driver rating (1-5 stars)
3. ✅ Tip option
4. ✅ Feedback text
5. ✅ Submit button

**API Calls:**
- POST `/api/v1/mobile/trips/{id}/rate`
  ```json
  {
    "rating": 5,
    "review": "Great driver!",
    "tip": 500
  }
  ```

**Riverpod Provider:**
- `submitRatingProvider` (async)

---

## Screen Flow Diagram

```
PassengerDashboard
    ↓ [Tap "Ride Now"]
TransportSelectionScreen (motorcycle/private car)
    ↓ [Select transport]
PickupLocationPage
    ↓ [Confirm pickup]
DestinationLocationPage
    ↓ [Confirm destination]
RouteSummaryPage (shows map + fare)
    ↓ [Confirm booking]
CreateTripPage (API call)
    ↓ [Trip created]
DriverMatchingScreen (search for drivers)
    ↓ [Driver assigned]
DriverAcceptedScreen (brief confirmation)
    ↓ [Driver arrives]
TripTrackingScreen (live tracking)
    ↓ [Trip completed]
TripCompletionPage (rate driver)
    ↓ [Submit]
PassengerDashboard (back to home)
```

---

## Riverpod Providers Needed

### Async Providers
```dart
// Route computation
final routeComputeProvider = FutureProvider.family<RouteData, RoutRequest>(...)

// Trip creation
final createTripProvider = FutureProvider.family<TripData, CreateTripRequest>(...)

// Rating submission
final submitRatingProvider = FutureProvider.family<void, RatingRequest>(...)
```

### Stream Providers (Real-time)
```dart
// Already defined in Phase 1:
final tripStatusStreamProvider = StreamProvider.family<Map?, int>(...)
final tripTrackingStreamProvider = StreamProvider.family<Map?, int>(...)
final driverLocationStreamProvider = StreamProvider.family<Map?, String>(...)
```

### State Notifiers (Complex Logic)
```dart
// Trip creation state machine
final tripCreationProvider = StateNotifierProvider<TripCreationNotifier, ...>(...)

// Driver matching state
final driverMatchingProvider = StateNotifierProvider<MatchingNotifier, ...>(...)
```

---

## API Models to Create

### lib/features/trips/data/models/
```dart
- create_trip_request.dart
- route_compute_request.dart
- route_compute_response.dart
- trip_data.dart
- driver_data.dart
- rating_request.dart
```

### lib/features/trips/data/datasources/
```dart
- trip_datasource.dart (API calls)
```

### lib/features/trips/data/repositories/
```dart
- trip_repository.dart (business logic)
```

---

## Testing Checklist

- [ ] Run `flutter analyze` - no errors
- [ ] Test pickup location selection
- [ ] Test destination selection
- [ ] Test route computation API call
- [ ] Test trip creation with valid data
- [ ] Test trip creation with invalid data
- [ ] Verify error dialogs appear
- [ ] Test RTDB stream (simulate events)
- [ ] Test driver matching screen
- [ ] Test trip tracking with live updates
- [ ] Test trip rating submission
- [ ] End-to-end flow works

---

## Estimated Timeline

```
3.1 Dashboard        - 30 min
3.2 Pickup Location  - 45 min
3.3 Destination      - 30 min (reuse 3.2 logic)
3.4 Route/Pricing    - 60 min
3.5 Trip Creation    - 30 min
3.6 Driver Matching  - 45 min
3.7 Trip Tracking    - 90 min (live updates complex)
3.8 Rating           - 30 min
Testing/Debugging    - 60 min
─────────────────────────────
TOTAL              - 6-8 hours
```

---

## Next Phase (Phase 4)

After Phase 3 is complete:
- Driver app implementation
- Trip request handling
- Driver navigation
- Earnings dashboard

---

## Success Criteria for Phase 3

✅ All screens implemented
✅ All API calls working
✅ All RTDB listeners functional
✅ Error handling comprehensive
✅ Full passenger flow works end-to-end
✅ No Firestore references
✅ All tests passing
✅ Code analysis clean
✅ Riverpod patterns correct

---

**Ready to begin Phase 3?** Let me know and I'll start implementation! 🚀
