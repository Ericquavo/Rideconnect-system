# RideConnect Flutter App Refactor Plan
**Date:** June 16, 2026
**Backend Status:** Production Ready (98/100, 280 tests passing)
**Scope:** Full RTDB migration, Firestore removal, API integration

---

## Phase 1: Foundation & Architecture (Priority: CRITICAL)

### 1.1 Remove Firestore Completely
- [ ] Identify all Firestore imports
- [ ] Remove `cloud_firestore` from pubspec.yaml
- [ ] Delete Firestore-based services
- [ ] Remove Firestore listeners/repositories
- [ ] Remove Firestore stream providers
- [ ] Update dependency injection

**Files to Remove/Modify:**
- Any file importing `cloud_firestore`
- FirestoreRepository classes
- FirestoreTripTracker
- FirestorePresenceManager
- Firestore-based state providers

### 1.2 Establish RTDB-Only Architecture
- [ ] Verify `firebase_database` in pubspec.yaml
- [ ] Create RTDBService for centralized access
- [ ] Define RTDB node structure
- [ ] Implement RTDB listeners
- [ ] Create real-time path constants

**RTDB Paths Required:**
```
drivers_online/{driver_id}
driver_locations/{driver_id}
active_trips/{trip_id}
trip_tracking/{trip_id}
presence/{user_id}
notification_queue/{user_id}
emergency_alerts/{user_id}
```

### 1.3 Fix Polling Issue (Critical Performance Fix)
**Current Problem:** `TripLifecycleManager` continuously polls `/trip-requests/{id}` causing excessive network traffic

**Solution:**
- [ ] Remove polling from TripLifecycleManager
- [ ] Replace with RTDB listener on `active_trips/{trip_id}`
- [ ] Keep API calls for:
  - Initial load
  - Manual refresh
  - Fallback recovery
  - App restart

---

## Phase 2: Authentication & State Management

### 2.1 Auth Repository & Service
- [ ] Create `AuthRepository` class
- [ ] Implement `POST /auth/mobile/login`
- [ ] Store token in secure storage
- [ ] Create token refresh/validation logic
- [ ] Implement auto-logout on token expiry
- [ ] Create auth state notifier (Riverpod)

**API Contract:**
```json
POST /api/v1/auth/mobile/login
{
  "phone": "+250780000000",
  "password": "password123",
  "device_name": "iPhone 13",
  "fcm_token": "fcm_token_string"
}
```

### 2.2 Interceptor & HTTP Client
- [ ] Create Dio HTTP client with Bearer token injection
- [ ] Implement error response parsing
- [ ] Add request/response logging
- [ ] Create retry mechanism

---

## Phase 3: Passenger App Implementation

### 3.1 Home Screen
- [ ] Display transport options (Motor Vehicle, Private Car, Public Bus)
- [ ] Load dynamically from API if available
- [ ] Show nearby drivers map
- [ ] Listen to `drivers_online/` RTDB node
- [ ] Render driver markers

### 3.2 Request Ride Flow
- [ ] Create RideRequestScreen
- [ ] Implement `POST /passenger/{type}/trip-request`
- [ ] Store trip_id locally
- [ ] Navigate to TripLifecycleScreen

### 3.3 Waiting for Driver Screen
- [ ] Listen to `active_trips/{trip_id}` instead of polling
- [ ] Handle status changes: REQUESTED → MATCHING → ASSIGNED → ACCEPTED
- [ ] Show estimated fare
- [ ] Display waiting message with search radius info

### 3.4 Trip Tracking Screen
- [ ] Initial fetch: `GET /mobile/trips/current`
- [ ] Switch to RTDB listener: `trip_tracking/{trip_id}`
- [ ] Display:
  - Driver marker
  - Passenger marker
  - ETA
  - Distance
  - Driver info & phone
  - Live route updates
  - Status badge

### 3.5 Trip Completion
- [ ] Detect RTDB status = COMPLETED
- [ ] Show fare summary
- [ ] Show payment screen
- [ ] Show rating screen
- [ ] Show trip receipt

### 3.6 Trip History
- [ ] Implement `GET /passenger/{type}/trip-history`
- [ ] Create UnifiedTripHistoryRepository
- [ ] Support:
  - Pagination
  - Filtering
  - Date ranges
  - Search
  - Trip details page

### 3.7 Public Bus Module
- [ ] Implement `GET /passenger/public-bus/routes`
- [ ] Implement `GET /passenger/public-bus/stops/{corridor_id}`
- [ ] Implement `POST /passenger/public-bus/book-seat`
- [ ] Show booking history
- [ ] Display ticket details
- [ ] QR code support if available

---

## Phase 4: Driver App Implementation

### 4.1 Driver Dashboard
- [ ] Show online/offline toggle
- [ ] Display vehicle info
- [ ] Show current earnings (today)
- [ ] List today's trips
- [ ] Show active trip status

### 4.2 Online/Offline Status
- [ ] Implement `POST /mobile/drivers/status`
- [ ] Update UI instantly on toggle
- [ ] Write to RTDB: `drivers_online/{driver_id}`

### 4.3 Driver Location Service
- [ ] Create background location service
- [ ] When online, POST `/mobile/drivers/live-location` every 3-5 seconds
- [ ] Send: { lat, lng, heading, speed }
- [ ] Update RTDB: `driver_locations/{driver_id}`
- [ ] When on active trip, also update: `trip_tracking/{trip_id}`

### 4.4 Incoming Trip Requests
- [ ] Listen to `drivers_online/{driver_id}/assigned_trip` (RTDB)
- [ ] Handle FCM notifications as backup
- [ ] Display:
  - Passenger info
  - Pickup location
  - Fare estimate
  - Distance
  - Accept/Reject buttons

### 4.5 Accept/Reject Trip
- [ ] Accept: `POST /mobile/drivers/trips/{id}/accept`
- [ ] Reject: `POST /mobile/drivers/trips/{id}/reject`
- [ ] Update local state
- [ ] Navigate to TripWorkflowScreen

### 4.6 Driver Trip Workflow
States: ASSIGNED → ACCEPTED → ARRIVED → STARTED → COMPLETED

- [ ] **Arrived:** `POST /driver/motor-vehicle/trip-requests/{id}/arrived`
- [ ] **Start Trip:** `PUT /mobile/drivers/trips/{id}/start`
- [ ] **Complete Trip:** `PUT /mobile/drivers/trips/{id}/complete`
- [ ] Show buttons: Arrived, Start Trip, Complete Trip, Call, Navigate, Emergency

### 4.7 Earnings
- [ ] Implement `GET /driver/earnings`
- [ ] Show:
  - Daily earnings
  - Weekly earnings
  - Monthly earnings
  - Completed trips count
  - Charts/graphs
  - Trip receipts

### 4.8 Driver History
- [ ] Trip history with pagination
- [ ] Trip details
- [ ] Passenger ratings
- [ ] Search functionality

---

## Phase 5: Notifications & Emergency

### 5.1 Push Notifications
- [ ] Setup `firebase_messaging`
- [ ] Handle foreground messages
- [ ] Handle background messages
- [ ] Handle terminated state
- [ ] Create notification center screen
- [ ] Show unread counters
- [ ] Navigate from notification

### 5.2 Emergency Module
- [ ] SOS button on trip screens
- [ ] Display emergency contacts
- [ ] Submit emergency report
- [ ] Listen to realtime alert updates

---

## Phase 6: Error Handling & User Experience

### 6.1 Error Response Parser
Support backend format:
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "pickup_lat": ["The pickup lat field is required."]
  }
}
```

- [ ] Create ErrorResponse model
- [ ] Parse validation errors
- [ ] Display field-level errors

### 6.2 Error UI Components
- [ ] ErrorDialog
- [ ] ErrorSnackbar
- [ ] ValidationErrorWidget
- [ ] NetworkErrorWidget
- [ ] EmptyStateWidget
- [ ] OfflineWidget

---

## Phase 7: Code Quality & Architecture

### 7.1 Clean Architecture Structure
```
lib/
  ├── features/
  │   ├── auth/
  │   │   ├── data/
  │   │   │   ├── datasources/
  │   │   │   ├── models/
  │   │   │   └── repositories/
  │   │   ├── domain/
  │   │   │   ├── entities/
  │   │   │   └── repositories/
  │   │   └── presentation/
  │   │       ├── screens/
  │   │       ├── widgets/
  │   │       └── providers/
  │   ├── passenger/
  │   │   ├── home/
  │   │   ├── ride_request/
  │   │   ├── trip_tracking/
  │   │   ├── trip_history/
  │   │   └── public_bus/
  │   ├── driver/
  │   │   ├── home/
  │   │   ├── trip_acceptance/
  │   │   ├── trip_workflow/
  │   │   └── earnings/
  │   └── common/
  │       ├── models/
  │       ├── widgets/
  │       └── services/
  ├── core/
  │   ├── errors/
  │   ├── models/
  │   ├── services/
  │   └── utils/
  └── config/
```

### 7.2 Repository Pattern
- [ ] Create repositories for each feature
- [ ] Separate data sources (API, RTDB, local)
- [ ] Implement caching strategy
- [ ] Error handling at repository level

### 7.3 State Management (Riverpod)
- [ ] Use `riverpod` consistently
- [ ] Create providers for:
  - Auth state
  - Trip state
  - Driver state
  - Location state
  - RTDB listeners
- [ ] No business logic in widgets

---

## Phase 8: Testing

### 8.1 Unit Tests
- [ ] Test repositories
- [ ] Test models
- [ ] Test providers
- [ ] Mock API responses
- [ ] Test error handling

### 8.2 Widget Tests
- [ ] Test screens
- [ ] Test widgets
- [ ] Test navigation
- [ ] Test state updates

### 8.3 Integration Tests
- [ ] End-to-end auth flow
- [ ] End-to-end trip flow
- [ ] Location updates
- [ ] RTDB listeners

---

## Priority Implementation Order

1. **CRITICAL:** Remove Firestore, establish RTDB
2. **CRITICAL:** Fix polling issue in TripLifecycleManager
3. **HIGH:** Auth repository & interceptor
4. **HIGH:** RTDB listeners
5. **HIGH:** Passenger ride request & tracking
6. **HIGH:** Driver online/offline & trip acceptance
7. **MEDIUM:** Trip history
8. **MEDIUM:** Public bus module
9. **MEDIUM:** Notifications
10. **LOW:** Emergency module, analytics

---

## Git Strategy

- Create feature branches for each phase
- Commit after each logical component
- Test before merging to main
- Tag release version after completion

---

## Success Criteria

✅ All Firestore removed
✅ RTDB-only architecture
✅ Zero polling (replaced with listeners)
✅ All API contracts implemented
✅ Clean architecture enforced
✅ Error handling complete
✅ Tests passing
✅ No compilation errors
✅ App builds for both Android/iOS
✅ Performance improved (no excessive polling)
