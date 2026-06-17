# RIDECONNECT FLUTTER APP REFACTOR PROMPT
**For: Flutter Copilot Code Generator**
**Status:** Backend production-ready (98/100, 280 tests passing)
**Date:** June 16, 2026

---

## EXECUTIVE SUMMARY

The RideConnect Flutter app must be completely refactored from a Firestore-based architecture to an RTDB-only architecture with full REST API integration. This prompt provides the complete specification, API contracts, and implementation details.

**Critical Issues to Fix:**
1. Remove ALL Firestore dependencies
2. Replace polling with RTDB listeners (TripLifecycleManager currently polls excessively)
3. Implement all verified API endpoints
4. Create clean architecture with repositories
5. Implement proper error handling

---

## PART 1: FOUNDATIONAL ARCHITECTURE

### Firebase Architecture (RTDB ONLY)

**Remove Completely:**
- `cloud_firestore` package
- FirebaseFirestore.instance
- CollectionReference usage
- DocumentReference usage
- Firestore listeners
- Firestore queries
- Any Firestore-based service

**Keep & Expand:**
- `firebase_database` package
- FirebaseDatabase.instance.ref()
- RTDB listeners
- RTDB transactions

### RTDB Node Structure (Required)

```
drivers_online/
  {driver_id}/
    status: "online" | "offline"
    lat: number
    lng: number
    updated_at: timestamp
    assigned_trip: {trip_id, passenger_name, pickup_location}

driver_locations/
  {driver_id}/
    lat: number
    lng: number
    heading: number
    speed: number
    updated_at: timestamp

active_trips/
  {trip_id}/
    status: "REQUESTED" | "MATCHING" | "ASSIGNED" | "ACCEPTED" | "ARRIVED" | "STARTED" | "COMPLETED" | "CANCELLED"
    passenger_id: number
    driver_id: number (null initially)
    pickup_location: string
    dropoff_location: string
    estimated_fare: number
    driver: {id, name, phone, vehicle_plate}
    updated_at: timestamp

trip_tracking/
  {trip_id}/
    driver_location: {lat, lng}
    passenger_location: {lat, lng}
    eta_minutes: number
    distance_km: number
    status: string
    updated_at: timestamp

presence/
  {user_id}/
    online: boolean
    last_seen: timestamp

notification_queue/
  {user_id}/
    {notification_id}/
      type: string
      title: string
      body: string
      data: object
      read: boolean
      created_at: timestamp

emergency_alerts/
  {user_id}/
    {alert_id}/
      trip_id: number
      location: {lat, lng}
      status: "ACTIVE" | "RESOLVED"
      created_at: timestamp
```

---

## PART 2: API CONTRACTS

### Authentication

```
POST /api/v1/auth/mobile/login

Request:
{
  "phone": "+250780000000",
  "password": "password123",
  "device_name": "iPhone 13",
  "fcm_token": "fcm_token_string"
}

Response (200):
{
  "success": true,
  "data": {
    "token": "3|AbCdEfGhIjKlMnOpQrStUvWxYz",
    "user": {
      "id": 1,
      "name": "John Doe",
      "phone": "+250780000000",
      "role": "PASSENGER" | "DRIVER"
    }
  }
}

Error (422):
{
  "success": false,
  "message": "The given data was invalid.",
  "errors": {
    "phone": ["The phone field is required."],
    "password": ["The password field is required."]
  }
}
```

### Passenger: Request Ride

```
POST /api/v1/passenger/{type}/trip-request
(where type = "motor-vehicle" or "private-car")

Request:
{
  "pickup_location": "Kigali Heights",
  "pickup_lat": -1.9546,
  "pickup_lng": 30.0934,
  "dropoff_location": "Kigali Convention Centre",
  "dropoff_lat": -1.9543,
  "dropoff_lng": 30.0967,
  "vehicle_type": "motorcycle" (optional for private-car)
}

Response (201):
{
  "success": true,
  "data": {
    "trip_id": 105,
    "status": "REQUESTED",
    "estimated_fare": 1500,
    "currency": "RWF"
  }
}

Action: Immediately navigate to trip tracking screen
RTDB initialized: active_trips/105
```

### Passenger: Get Current Active Trip

```
GET /api/v1/mobile/trips/current

Response (200):
{
  "success": true,
  "data": {
    "trip_id": 105,
    "trip_state": "ACCEPTED",
    "driver": {
      "id": 42,
      "name": "Jane Driver",
      "vehicle_plate": "RAB 123 C",
      "phone": "+250781111111"
    },
    "driver_location": {
      "lat": -1.9550,
      "lng": 30.0940
    },
    "eta": "4 mins",
    "fare": 1500
  }
}

Action: After initial fetch, switch to RTDB listener active_trips/{trip_id}
```

### Passenger: Trip History

```
GET /api/v1/passenger/{type}/trip-history?page=1&per_page=20

Response (200):
{
  "success": true,
  "data": [
    {
      "trip_id": 100,
      "status": "COMPLETED",
      "pickup_location": "Location A",
      "dropoff_location": "Location B",
      "fare": 1500,
      "currency": "RWF",
      "driver": {name, phone, rating},
      "completed_at": "2026-06-15T14:30:00"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total": 100
  }
}
```

### Passenger: Cancel Trip

```
POST /api/v1/passenger/motor-vehicle/trip-requests/{id}/cancel

Request:
{
  "reason": "Driver is taking too long" (optional)
}

Response (200):
{
  "success": true,
  "message": "Trip cancelled successfully"
}

RTDB: active_trips/{id}/status = "CANCELLED"
```

### Passenger: Rate Trip

```
POST /api/v1/passenger/{type}/trip-requests/{id}/rate

Request:
{
  "rating": 5,
  "comment": "Great driver!" (optional)
}

Response (200):
{
  "success": true,
  "message": "Rating submitted"
}
```

### Passenger: Public Bus Book Seat

```
POST /api/v1/passenger/public-bus/book-seat

Request:
{
  "corridor_id": 1,
  "boarding_stop_id": 5,
  "destination_stop_id": 12,
  "seats_reserved": 1
}

Response (201):
{
  "success": true,
  "data": {
    "booking_id": 201,
    "ticket_number": "TICKET-2026-0001",
    "boarding_stop": {name, location, time},
    "destination_stop": {name, location},
    "fare": 500,
    "status": "CONFIRMED"
  }
}
```

### Driver: Update Status

```
POST /api/v1/mobile/drivers/status

Request:
{
  "status": "online" | "offline",
  "lat": -1.9546,
  "lng": 30.0934
}

Response (200):
{
  "success": true,
  "message": "Status updated successfully"
}

RTDB: drivers_online/{driver_id} updated
```

### Driver: Post Live Location

```
POST /api/v1/mobile/drivers/live-location

Request (send every 3-5 seconds when online):
{
  "lat": -1.9548,
  "lng": 30.0938,
  "heading": 120.5,
  "speed": 15.2
}

Response (200):
{
  "success": true
}

RTDB: 
  - driver_locations/{driver_id} updated
  - trip_tracking/{trip_id} updated (if on active trip)
```

### Driver: Accept Trip

```
POST /api/v1/mobile/drivers/trips/{id}/accept

Request: {} (empty body)

Response (200):
{
  "success": true,
  "data": {
    "trip_id": 105,
    "status": "ACCEPTED",
    "passenger": {
      "name": "John Doe",
      "phone": "+250780000000",
      "rating": 4.8
    },
    "pickup_location": "Kigali Heights",
    "dropoff_location": "Kigali Convention Centre"
  }
}

RTDB: active_trips/{id}/status = "ACCEPTED", driver_id assigned
```

### Driver: Reject Trip

```
POST /api/v1/mobile/drivers/trips/{id}/reject

Request:
{
  "reason": "Too far" (optional)
}

Response (200):
{
  "success": true,
  "message": "Trip rejected"
}

RTDB: active_trips/{id} removed from driver queue
```

### Driver: Mark Arrived

```
POST /api/v1/driver/motor-vehicle/trip-requests/{id}/arrived

Request: {} (empty)

Response (200):
{
  "success": true
}

RTDB: active_trips/{id}/status = "ARRIVED"
```

### Driver: Start Trip

```
PUT /api/v1/mobile/drivers/trips/{id}/start

Request: {} (empty)

Response (200):
{
  "success": true
}

RTDB: active_trips/{id}/status = "STARTED"
```

### Driver: Complete Trip

```
PUT /api/v1/mobile/drivers/trips/{id}/complete

Request: {} (empty)

Response (200):
{
  "success": true,
  "data": {
    "trip_id": 105,
    "status": "COMPLETED",
    "fare": 1500,
    "driver_earnings": 900
  }
}

RTDB: active_trips/{id}/status = "COMPLETED"
```

### Driver: Get Earnings

```
GET /api/v1/driver/earnings?period=today

Response (200):
{
  "success": true,
  "data": {
    "total_earnings": 12500,
    "completed_trips": 8,
    "period": "today",
    "breakdown": {
      "daily": 12500,
      "weekly": 85000,
      "monthly": 350000
    }
  }
}
```

---

## PART 3: IMPLEMENTATION SPECIFICATIONS

### Phase 1: Authentication & Setup

**1.1 Create Auth Repository**

```dart
// lib/features/auth/data/repositories/auth_repository.dart

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorageService storageService;

  Future<AuthResponse> login({
    required String phone,
    required String password,
    required String deviceName,
    required String fcmToken,
  }) async {
    // POST /api/v1/auth/mobile/login
    // Store token in secure storage
    // Return AuthResponse with user data and token
  }

  Future<String?> getStoredToken() async {
    // Retrieve token from secure storage
  }

  Future<void> logout() async {
    // Clear secure storage
    // POST /api/v1/auth/logout
  }

  Future<bool> validateToken() async {
    // GET /api/v1/auth/token/validate
  }
}
```

**1.2 Create HTTP Client with Interceptors**

```dart
// lib/core/services/http_client.dart

class ApiClient {
  final Dio dio;
  final AuthRepository authRepository;

  ApiClient({required this.dio, required this.authRepository}) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    // 1. Request interceptor - add Bearer token
    // 2. Response interceptor - handle errors
    // 3. Error interceptor - retry on 401/token expiry
  }
}
```

**1.3 Create Auth State Provider (Riverpod)**

```dart
// lib/features/auth/presentation/providers/auth_provider.dart

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  // AuthNotifier manages login, logout, token validation
  // Tracks current user
  // Handles auto-refresh
});
```

---

### Phase 2: Passenger App - Home & Request

**2.1 Home Screen**

- Display nearby drivers map (listen to `drivers_online/` RTDB)
- Show transport options (Motor Vehicle, Private Car, Public Bus)
- Each option navigates to request screen

**2.2 Ride Request Screen**

```dart
// lib/features/passenger/presentation/screens/ride_request_screen.dart

class RideRequestScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Get user location (geolocator)
    // 2. Get drop-off location (from user or Places)
    // 3. Display pickup/dropoff form
    // 4. Show estimated fare (optional)
    // 5. Button: "Request Ride"
    //    - POST /api/v1/passenger/{type}/trip-request
    //    - On success: navigate to TripLifecycleScreen
    //    - On error: show error dialog
  }
}
```

---

### Phase 3: Passenger App - Trip Tracking (CRITICAL FIX)

**3.1 Remove Polling - Replace with RTDB Listener**

```dart
// lib/features/passenger/data/services/trip_lifecycle_manager.dart

// BEFORE (Remove this):
// Timer.periodic() continuously polling GET /trip-requests/{id}

// AFTER (Replace with):
StreamSubscription<DatabaseEvent> _tripListener;

void listenToTripUpdates(int tripId) {
  _tripListener = FirebaseDatabase.instance
    .ref('active_trips/$tripId')
    .onValue
    .listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        _handleTripUpdate(data);
      }
    });
}

// Only keep API calls for:
// - Initial load (GET /mobile/trips/current)
// - Manual refresh (pull-to-refresh)
// - Fallback if RTDB connection fails
```

**3.2 Trip Tracking Screen**

```dart
// lib/features/passenger/presentation/screens/trip_tracking_screen.dart

class TripTrackingScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripState = ref.watch(tripProvider);
    
    // 1. Initial load: GET /mobile/trips/current
    // 2. Listen: FirebaseDatabase.instance.ref('trip_tracking/$tripId')
    // 3. Display:
    //    - Google Map with driver marker
    //    - Passenger marker
    //    - ETA
    //    - Distance
    //    - Driver info (name, phone, vehicle)
    //    - Live route polyline
    // 4. Update UI in real-time from RTDB
    // 5. On status COMPLETED:
    //    - Show fare summary
    //    - Navigate to rating screen
  }
}
```

---

### Phase 4: Driver App - Online & Location

**4.1 Driver Home**

- Toggle online/offline status
- Show vehicle info
- Show today's earnings
- Show active trip status

**4.2 Online/Offline Toggle**

```dart
// lib/features/driver/presentation/providers/driver_status_provider.dart

final driverStatusProvider = StateNotifierProvider<
    DriverStatusNotifier,
    DriverStatusState>((ref) {
  // Manages online/offline state
});

class DriverStatusNotifier extends StateNotifier<DriverStatusState> {
  Future<void> goOnline() async {
    // POST /api/v1/mobile/drivers/status
    // {status: "online", lat, lng}
    // Write to RTDB: drivers_online/{driver_id}
  }

  Future<void> goOffline() async {
    // POST /api/v1/mobile/drivers/status
    // {status: "offline"}
    // Update RTDB: drivers_online/{driver_id}
    // Stop location service
  }
}
```

**4.3 Background Location Service**

```dart
// lib/features/driver/services/driver_location_service.dart

class DriverLocationService {
  Timer? _locationTimer;

  void startLocationTracking() {
    // When driver online:
    // Every 3-5 seconds:
    // 1. Get current location (geolocator)
    // 2. POST /api/v1/mobile/drivers/live-location
    // 3. Update RTDB driver_locations/{driver_id}
    // 4. If on active trip, update trip_tracking/{trip_id}
  }

  void stopLocationTracking() {
    _locationTimer?.cancel();
  }
}
```

---

### Phase 5: Driver App - Trip Acceptance & Workflow

**5.1 Incoming Trip Requests**

```dart
// Listen to RTDB: drivers_online/{driver_id}/assigned_trip
// Show dialog/screen with:
// - Passenger name & phone
// - Pickup location
// - Dropoff location
// - Fare estimate
// - Accept / Reject buttons

FirebaseDatabase.instance
  .ref('drivers_online/$driverId/assigned_trip')
  .onValue
  .listen((event) {
    if (event.snapshot.exists) {
      // Show incoming trip dialog
      _showIncomingTripDialog(event.snapshot.value);
    }
  });
```

**5.2 Trip Workflow**

```dart
// lib/features/driver/presentation/screens/trip_workflow_screen.dart

class TripWorkflowScreen extends ConsumerWidget {
  // States: ASSIGNED → ACCEPTED → ARRIVED → STARTED → COMPLETED

  // Buttons:
  // - ACCEPTED: "I've Arrived" button
  //   POST /driver/motor-vehicle/trip-requests/{id}/arrived
  // - ARRIVED: "Start Trip" button
  //   PUT /mobile/drivers/trips/{id}/start
  // - STARTED: "Complete Trip" button
  //   PUT /mobile/drivers/trips/{id}/complete
  // - COMPLETED: Show earnings, navigate to home

  // Always show:
  // - Call Passenger button
  // - Open Navigation (Google Maps)
  // - Emergency button
}
```

---

### Phase 6: Error Handling & Models

**6.1 Error Response Model**

```dart
// lib/core/models/error_response.dart

class ErrorResponse {
  final bool success;
  final String message;
  final Map<String, List<String>> errors;

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    return ErrorResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? 'An error occurred',
      errors: Map<String, List<String>>.from(
        (json['errors'] as Map?)?.map(
          (key, value) => MapEntry(
            key,
            List<String>.from(value as List),
          ),
        ) ?? {},
      ),
    );
  }
}
```

**6.2 Error Dialog Widget**

```dart
// lib/core/widgets/error_dialog.dart

void showErrorDialog(BuildContext context, ErrorResponse error) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Error'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error.message),
          if (error.errors.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: error.errors.entries
                    .map((e) => Text('• ${e.key}: ${e.value.first}'))
                    .toList(),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

---

### Phase 7: Cleanup & Architecture

**7.1 pubspec.yaml**

Remove:
```yaml
cloud_firestore: ^4.x.x
```

Keep/Verify:
```yaml
firebase_database: ^10.x.x
firebase_messaging: ^14.x.x
dio: ^5.x.x
riverpod: ^2.x.x
geolocator: ^9.x.x
google_maps_flutter: ^2.x.x
secure_storage: ^9.x.x
```

**7.2 Directory Structure**

```
lib/
├── core/
│   ├── models/
│   │   ├── error_response.dart
│   │   └── api_response.dart
│   ├── services/
│   │   ├── http_client.dart
│   │   ├── rtdb_service.dart
│   │   └── storage_service.dart
│   ├── widgets/
│   │   ├── error_dialog.dart
│   │   ├── error_snackbar.dart
│   │   └── loading_widget.dart
│   └── constants/
│       └── rtdb_paths.dart
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
│   │   ├── earnings/
│   │   └── services/
│   └── common/
│       ├── models/
│       ├── widgets/
│       └── services/
└── main.dart
```

---

## PART 4: PRIORITY TASKS (IMPLEMENTATION ORDER)

### Week 1: Foundation
- [ ] Remove Firestore from pubspec.yaml
- [ ] Remove all Firestore imports
- [ ] Create RTDBService
- [ ] Create AuthRepository & login flow
- [ ] Create HTTP client with interceptors
- [ ] Create error handling
- [ ] Create auth provider (Riverpod)

### Week 2: Passenger App
- [ ] Create home screen with nearby drivers
- [ ] Create ride request screen
- [ ] **FIX: Remove polling from TripLifecycleManager**
- [ ] Create RTDB listeners for active_trips
- [ ] Create trip tracking screen with RTDB
- [ ] Create trip completion flow

### Week 3: Driver App
- [ ] Create driver home
- [ ] Implement online/offline toggle
- [ ] Create background location service
- [ ] Implement incoming trip listener (RTDB)
- [ ] Create trip acceptance/rejection
- [ ] Create trip workflow screen

### Week 4: Polish & Testing
- [ ] Implement trip history
- [ ] Implement public bus booking
- [ ] Implement notifications
- [ ] Implement emergency module
- [ ] Unit tests
- [ ] Widget tests
- [ ] Bug fixes

---

## PART 5: VERIFICATION CHECKLIST

### Firestore Removal
- [ ] No `cloud_firestore` in pubspec.yaml
- [ ] No `FirebaseFirestore.instance` in code
- [ ] No CollectionReference usage
- [ ] No Firestore listeners
- [ ] Code compiles without Firestore

### RTDB Implementation
- [ ] Listening to drivers_online/
- [ ] Listening to active_trips/
- [ ] Listening to trip_tracking/
- [ ] Listening to driver_locations/
- [ ] All RTDB listeners unsubscribed on cleanup

### Polling Fix
- [ ] TripLifecycleManager has NO polling
- [ ] Uses RTDB listener instead
- [ ] API calls only for initial load
- [ ] No excessive network traffic

### API Integration
- [ ] All login endpoint implemented ✓
- [ ] All passenger endpoints implemented ✓
- [ ] All driver endpoints implemented ✓
- [ ] All public bus endpoints implemented ✓
- [ ] Error responses parsed correctly ✓

### State Management
- [ ] All features use Riverpod
- [ ] No business logic in widgets
- [ ] Repositories separate from UI
- [ ] State properly invalidated on logout

### Error Handling
- [ ] 422 validation errors parsed
- [ ] Network errors handled
- [ ] RTDB connection failures handled
- [ ] Error dialogs/snackbars shown

---

## PART 6: SUCCESS CRITERIA

✅ App builds without Firestore dependency
✅ Login works with verified backend
✅ Passenger can request ride
✅ Trip tracking updates via RTDB (not polling)
✅ Driver can go online/offline
✅ Driver can accept/reject trips
✅ Location service running in background
✅ Notifications working
✅ No 500/404 errors on valid requests
✅ Performance improved (no excessive polling)
✅ All tests passing
✅ Code follows clean architecture

---

## BACKEND REFERENCE

**Base URL:** https://rideconnect-emp0.onrender.com/api/v1
**ML Service:** https://ml-service-j72g.onrender.com
**DB:** PostgreSQL via Supabase
**Realtime:** Firebase RTDB only (NO Firestore)
**Auth:** Sanctum Bearer tokens (NO JWT auto-refresh)

**Backend Production Readiness:** 98/100
**Test Success Rate:** 100% (280 tests)
**Verified APIs:** All 40+ endpoints tested

---

This prompt can be delivered to your Flutter code generator or development team to implement the complete refactoring systematically.
