# Phase 4: Driver App Implementation - Complete Backend Integration

## Project Context

**Current Status:** Phases 1-3 Complete (Foundation, Auth, Passenger App)
**Backend Status:** ✅ 98/100 Production Readiness, 280/280 Tests Passed
**Architecture:** RTDB-only (Firestore completely removed)
**Backend Base URL:** https://rideconnect-emp0.onrender.com/api/v1
**ML Service:** https://ml-service-j72g.onrender.com

## Phase 4 Objectives

Implement complete Driver App functionality with full backend integration, RTDB real-time updates, and production-ready features.

---

## CRITICAL PASSENGER UPDATE: Multiple Active Trip Prevention

**Priority:** HIGH - Must be implemented before Phase 4 completion
**Status:** Backend implemented, Flutter integration required

### Backend Enforcement
The Laravel backend now enforces that passengers can only have **one active trip at a time**. When a passenger attempts to create a new trip while one is already in progress (REQUESTED, MATCHING, ASSIGNING, ASSIGNED, ACCEPTED, or STARTED states), the backend blocks the request with:

```
HTTP Status: 409 Conflict

Response:
{
  "success": false,
  "error_code": "ACTIVE_TRIP_EXISTS",
  "message": "There is another trip in progress.",
  "data": {
    "trip_id": 1234,
    "status": "ASSIGNED",
    "can_cancel": true
  }
}
```

### Flutter Implementation Requirements

#### 1. Update Trip Creation Error Handling

**File to Update:** `lib/features/trips/data/datasources/trips_datasource.dart`

```dart
@override
Future<CreateTripResponse> createTrip(CreateTripRequest request) async {
  try {
    final response = await _dio.post('/passenger/${request.vehicleType}/trip-request', data: request.toJson());
    return CreateTripResponse.fromJson(response.data['data']);
  } on DioException catch (e) {
    if (e.response?.statusCode == 409 && 
        e.response?.data['error_code'] == 'ACTIVE_TRIP_EXISTS') {
      // Return specific exception for active trip conflict
      throw ActiveTripExistsException(
        tripId: e.response?.data['data']['trip_id'],
        status: e.response?.data['data']['status'],
        canCancel: e.response?.data['data']['can_cancel'] ?? false,
      );
    }
    throw _handleError(e);
  }
}
```

#### 2. Create ActiveTripExistsException

**File to Create:** `lib/features/trips/data/exceptions/active_trip_exists_exception.dart`

```dart
class ActiveTripExistsException implements Exception {
  final int tripId;
  final String status;
  final bool canCancel;

  ActiveTripExistsException({
    required this.tripId,
    required this.status,
    required this.canCancel,
  });

  @override
  String toString() => 'ActiveTripExistsException: Trip $tripId is currently $status';
}
```

#### 3. Update Trip Creation Provider

**File to Update:** `lib/features/trips/presentation/providers/trips_provider.dart`

```dart
class CreateTripNotifier extends StateNotifier<CreateTripState> {
  final ITripsRepository _repository;

  CreateTripNotifier(this._repository) : super(CreateTripInitial());

  Future<void> createTrip(CreateTripRequest request) async {
    state = CreateTripLoading();
    try {
      final response = await _repository.createTrip(request);
      state = CreateTripSuccess(response);
    } on ActiveTripExistsException catch (e) {
      state = CreateTripActiveTripConflict(
        tripId: e.tripId,
        status: e.status,
        canCancel: e.canCancel,
      );
    } catch (e) {
      state = CreateTripError(_parseError(e));
    }
  }
}
```

#### 4. Add Conflict State

**File to Update:** `lib/features/trips/presentation/providers/trips_provider.dart`

```dart
abstract class CreateTripState {}

class CreateTripInitial extends CreateTripState {}
class CreateTripLoading extends CreateTripState {}
class CreateTripSuccess extends CreateTripState {
  final CreateTripResponse response;
  CreateTripSuccess(this.response);
}
class CreateTripError extends CreateTripState {
  final String message;
  CreateTripError(this.message);
}
class CreateTripActiveTripConflict extends CreateTripState {
  final int tripId;
  final String status;
  final bool canCancel;
  CreateTripActiveTripConflict({
    required this.tripId,
    required this.status,
    required this.canCancel,
  });
}
```

#### 5. Update DriverMatchingPage to Handle Conflict

**File to Update:** `lib/features/trips/presentation/pages/driver_matching_page.dart`

```dart
// In the build method, handle CreateTripActiveTripConflict state
Widget _buildState(BuildContext context, CreateTripState state) {
  if (state is CreateTripActiveTripConflict) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showActiveTripDialog(context, state);
    });
  }
  // ... existing state handling
}

void _showActiveTripDialog(BuildContext context, CreateTripActiveTripConflict state) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text("Trip in Progress"),
      content: const Text("You already have an active trip. Please track or cancel your existing trip before creating a new one."),
      actions: [
        if (state.canCancel)
          TextButton(
            child: const Text("Cancel Trip"),
            onPressed: () {
              Navigator.pop(context);
              _cancelExistingTrip(context, state.tripId);
            },
          ),
        ElevatedButton(
          child: const Text("Track Trip"),
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(
              context,
              '/tripTracking',
              arguments: state.tripId,
            );
          },
        ),
      ],
    ),
  );
}

Future<void> _cancelExistingTrip(BuildContext context, int tripId) async {
  try {
    final repository = ref.read(tripsRepositoryProvider);
    await repository.cancelTrip(tripId, reason: "Creating new trip instead");
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Previous trip cancelled. You can now request a new ride.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to cancel trip: ${e.toString()}')),
    );
  }
}
```

#### 6. Update RouteSummaryPage to Handle Conflict

**File to Update:** `lib/features/trips/presentation/pages/route_summary_page.dart`

Apply the same conflict handling pattern as DriverMatchingPage since trip creation is initiated from both screens.

### RTDB Integration

**IMPORTANT:** When a 409 Conflict is received:
- Do NOT create local state for the rejected trip
- Use the `trip_id` from the 409 response to immediately re-subscribe to RTDB:
  - `active_trips/{trip_id}`
  - `trip_tracking/{trip_id}`
- This ensures the Flutter app stays synchronized with the backend's source of truth

### Testing Requirements

```dart
// test/features/trips/data/datasources/trips_datasource_test.dart
test('createTrip throws ActiveTripExistsException on 409', () async {
  // Mock Dio to return 409 response
  // Verify exception is thrown with correct data
});

// test/features/trips/presentation/providers/trips_provider_test.dart
test('createTrip emits CreateTripActiveTripConflict on 409', () async {
  // Mock repository to throw ActiveTripExistsException
  // Verify state transition
});

// test/features/trips/presentation/pages/driver_matching_page_test.dart
testWidgets('shows active trip dialog on conflict', (tester) async {
  // Pump widget with CreateTripActiveTripConflict state
  // Verify dialog is displayed
  // Verify buttons work correctly
});
```

---

## CRITICAL ARCHITECTURE RULES

### RTDB-Only Architecture (NO FIRESTORE)
- ❌ **REMOVE ALL** FirebaseFirestore dependencies
- ❌ **REMOVE ALL** Firestore listeners, repositories, services
- ✅ **USE ONLY** firebase_database for real-time operations
- ✅ **USE** FirebaseDatabase.instance.ref() for all realtime operations

### Required RTDB Nodes
```
drivers_online/
driver_locations/
active_trips/
trip_tracking/
presence/
notification_queue/
emergency_alerts/
```

### State Management
- Use Riverpod consistently (already configured in Phases 1-3)
- Follow Clean Architecture: UI → Provider → Repository → DataSource → API
- No networking logic inside widgets
- Separate concerns: Models, Repositories, DataSources, State, UI

---

## DRIVER APP IMPLEMENTATION REQUIREMENTS

### 1. Driver Authentication (Already Complete - Reuse)
- ✅ POST /api/v1/auth/mobile/login (shared with passenger)
- ✅ Token storage and refresh (already implemented)
- ✅ Role-based routing (already implemented)

### 2. Driver Dashboard Screen

**Features to Implement:**
- Online/Offline status toggle
- Vehicle information display
- Current earnings summary
- Today's trip count
- Active trip status card
- Incoming trip request indicator

**API Endpoints:**
```
GET /api/v1/mobile/drivers/profile
POST /api/v1/mobile/drivers/status
```

**RTDB Listeners:**
- Listen to `drivers_online/{driver_id}` for status updates
- Listen to `drivers_online/{driver_id}/assigned_trip` for incoming requests

### 3. Driver Online/Offline Status

**API Endpoint:**
```
POST /api/v1/mobile/drivers/status

Request:
{
  "status": "online" | "offline",
  "lat": -1.9546,
  "lng": 30.0934
}

Response:
{
  "success": true,
  "message": "Status updated successfully"
}
```

**RTDB Integration:**
- When going online: Write to `drivers_online/{driver_id}`
- When going offline: Remove from `drivers_online/{driver_id}`
- Update UI instantly on status change

### 4. Driver Location Service (Background)

**Requirements:**
- Create background service using flutter_background_service
- When online: Update location every 3-5 seconds
- When on active trip: Update location every 3-5 seconds

**API Endpoint:**
```
POST /api/v1/mobile/drivers/live-location

Request:
{
  "lat": -1.9548,
  "lng": 30.0938,
  "heading": 120.5,
  "speed": 15.2
}

Response:
{
  "success": true
}
```

**RTDB Integration:**
- Always update: `driver_locations/{driver_id}`
- When on trip: Also update `trip_tracking/{trip_id}`

**Implementation:**
```dart
// Create: lib/features/driver/services/driver_location_service.dart
class DriverLocationService {
  // Background location tracking
  // Periodic API calls to /mobile/drivers/live-location
  // RTDB updates to driver_locations/{driver_id}
  // RTDB updates to trip_tracking/{trip_id} when on trip
}
```

### 5. Incoming Trip Requests

**DO NOT POLL APIs** - Use RTDB listeners or FCM

**RTDB Listener:**
```
Listen to: drivers_online/{driver_id}/assigned_trip

Data structure:
{
  "trip_id": 105,
  "passenger": {
    "name": "John Doe",
    "phone": "+250780000000",
    "rating": 4.8
  },
  "pickup_location": "Kigali Heights",
  "pickup_lat": -1.9546,
  "pickup_lng": 30.0934,
  "dropoff_location": "Kigali Convention Centre",
  "dropoff_lat": -1.9543,
  "dropoff_lng": 30.0967,
  "estimated_fare": 1500,
  "distance": "3.2 km",
  "duration": "8 mins",
  "vehicle_type": "motorcycle"
}
```

**Screen to Implement:**
```dart
// Create: lib/features/driver/presentation/pages/incoming_trip_request_page.dart
- Show passenger info
- Show pickup/dropoff locations
- Show fare estimate
- Show distance/duration
- Accept button (calls API)
- Reject button (calls API)
- Auto-reject after 30 seconds (configurable)
- Sound/vibration notification
```

### 6. Accept Trip

**API Endpoint:**
```
POST /api/v1/mobile/drivers/trips/{id}/accept

Request: Empty body

Response:
{
  "success": true,
  "data": {
    "trip_id": 105,
    "status": "ACCEPTED",
    "passenger": {
      "name": "John Doe",
      "phone": "+250780000000"
    }
  }
}
```

**RTDB Trigger:** `active_trips/{id}` state updated to ACCEPTED

**Flow:**
1. User taps "Accept"
2. Call API endpoint
3. Update local state
4. Navigate to Driver Trip Workflow Screen
5. Start listening to `active_trips/{trip_id}`

### 7. Reject Trip

**API Endpoint:**
```
POST /api/v1/mobile/drivers/trips/{id}/reject

Request: Empty body

Response:
{
  "success": true,
  "message": "Trip rejected successfully"
}
```

**Flow:**
1. User taps "Reject"
2. Call API endpoint
3. Return to waiting mode
4. Clear local trip state
5. Continue listening for new requests

### 8. Driver Trip Workflow Screen

**States to Handle:**
- ASSIGNED (initial state after acceptance)
- ACCEPTED (driver confirmed)
- ARRIVED (driver at pickup)
- STARTED (trip in progress)
- COMPLETED (trip finished)
- CANCELLED (trip cancelled)
- FAILED (error state)

**Screen to Implement:**
```dart
// Create: lib/features/driver/presentation/pages/driver_trip_workflow_page.dart

Features:
- Display current trip status prominently
- Show passenger information
- Show pickup/dropoff locations
- Show route map (placeholder for now)
- Context-sensitive action buttons:
  * ARRIVED state: Show "Arrived" button
  * ACCEPTED state: Show "Navigate to Pickup" button
  * STARTED state: Show "Complete Trip" button
- Call passenger button
- Message passenger button
- Open navigation button (Google Maps)
- Emergency button
- Real-time status updates via RTDB
```

**State Transitions:**

**ARRIVED:**
```
POST /api/v1/driver/motor-vehicle/trip-requests/{id}/arrived

Request: Empty body

Response:
{
  "success": true,
  "data": {
    "trip_id": 105,
    "status": "ARRIVED"
  }
}
```

**START TRIP:**
```
PUT /api/v1/mobile/drivers/trips/{id}/start

Request: Empty body

Response:
{
  "success": true,
  "data": {
    "trip_id": 105,
    "status": "STARTED",
    "started_at": "2024-01-15T10:30:00Z"
  }
}
```

**COMPLETE TRIP:**
```
PUT /api/v1/mobile/drivers/trips/{id}/complete

Request: Empty body

Response:
{
  "success": true,
  "data": {
    "trip_id": 105,
    "status": "COMPLETED",
    "completed_at": "2024-01-15T11:00:00Z",
    "fare": 1500,
    "currency": "RWF"
  }
}
```

### 9. Driver Earnings Dashboard

**API Endpoint:**
```
GET /api/v1/driver/earnings

Response:
{
  "success": true,
  "data": {
    "today": {
      "earnings": 15000,
      "trips": 8,
      "hours_online": 6.5
    },
    "week": {
      "earnings": 85000,
      "trips": 45,
      "hours_online": 38.2
    },
    "month": {
      "earnings": 320000,
      "trips": 180,
      "hours_online": 145.0
    },
    "recent_trips": [
      {
        "trip_id": 105,
        "fare": 1500,
        "completed_at": "2024-01-15T11:00:00Z",
        "passenger_rating": 5
      }
    ]
  }
}
```

**Screen to Implement:**
```dart
// Create: lib/features/driver/presentation/pages/earnings_dashboard_page.dart

Features:
- Daily earnings card
- Weekly earnings card
- Monthly earnings card
- Trips count
- Hours online
- Earnings chart (placeholder for now)
- Recent trips list
- Trip details navigation
- Date range filter
- Export earnings (placeholder)
```

### 10. Driver Trip History

**API Endpoint:**
```
GET /api/v1/mobile/drivers/trips/history?page=1&per_page=20

Response:
{
  "success": true,
  "data": {
    "trips": [
      {
        "trip_id": 105,
        "status": "COMPLETED",
        "pickup_location": "Kigali Heights",
        "dropoff_location": "Kigali Convention Centre",
        "fare": 1500,
        "completed_at": "2024-01-15T11:00:00Z",
        "passenger": {
          "name": "John Doe",
          "rating": 4.8
        }
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total": 180,
      "last_page": 9
    }
  }
}
```

**Screen to Implement:**
```dart
// Create: lib/features/driver/presentation/pages/driver_trip_history_page.dart

Features:
- Trip history list with pagination
- Trip details page
- Passenger ratings display
- Search by date/passenger
- Filter by status
- Filter by vehicle type
- Pull-to-refresh
- Infinite scroll
```

### 11. Driver Profile Management

**API Endpoints:**
```
GET /api/v1/mobile/drivers/profile
PUT /api/v1/mobile/drivers/profile

Request (PUT):
{
  "name": "Jane Driver",
  "phone": "+250781111111",
  "vehicle_plate": "RAB 123 C",
  "vehicle_type": "motorcycle",
  "vehicle_color": "Red"
}
```

**Screen to Implement:**
```dart
// Create: lib/features/driver/presentation/pages/driver_profile_page.dart

Features:
- Display driver information
- Edit profile form
- Vehicle information
- Document upload (placeholder)
- Rating display
- Total trips display
- Join date display
- Logout button
```

---

## DATA LAYER IMPLEMENTATION

### Models to Create

```dart
// lib/features/driver/data/models/driver_models.dart

class DriverProfile {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? vehiclePlate;
  final String? vehicleType;
  final String? vehicleColor;
  final double? rating;
  final int? totalTrips;
  final String? joinedAt;
  // ... @JsonSerializable
}

class DriverStatusRequest {
  final String status; // "online" | "offline"
  final double lat;
  final double lng;
  // ... @JsonSerializable
}

class DriverLocationUpdate {
  final double lat;
  final double lng;
  final double heading;
  final double speed;
  // ... @JsonSerializable
}

class DriverEarnings {
  final EarningsPeriod today;
  final EarningsPeriod week;
  final EarningsPeriod month;
  final List<RecentTrip> recentTrips;
  // ... @JsonSerializable
}

class EarningsPeriod {
  final double earnings;
  final int trips;
  final double hoursOnline;
  // ... @JsonSerializable
}

class TripRequest {
  final int tripId;
  final PassengerInfo passenger;
  final String pickupLocation;
  final double pickupLat;
  final double pickupLng;
  final String dropoffLocation;
  final double dropoffLat;
  final double dropoffLng;
  final double estimatedFare;
  final String distance;
  final String duration;
  final String vehicleType;
  // ... @JsonSerializable
}

class PassengerInfo {
  final String name;
  final String phone;
  final double? rating;
  // ... @JsonSerializable
}
```

### DataSource to Create

```dart
// lib/features/driver/data/datasources/driver_datasource.dart

abstract class IDriverDataSource {
  // Profile
  Future<DriverProfile> getProfile();
  Future<DriverProfile> updateProfile(DriverProfile profile);
  
  // Status
  Future<void> updateStatus(DriverStatusRequest request);
  
  // Location
  Future<void> updateLocation(DriverLocationUpdate location);
  
  // Trips
  Future<void> acceptTrip(int tripId);
  Future<void> rejectTrip(int tripId);
  Future<void> arriveAtPickup(int tripId);
  Future<void> startTrip(int tripId);
  Future<void> completeTrip(int tripId);
  
  // Earnings
  Future<DriverEarnings> getEarnings();
  
  // History
  Future<TripsListResponse> getTripHistory(int page, int perPage);
}

class DriverDataSource implements IDriverDataSource {
  final Dio _dio;
  
  // Implement all methods with proper error handling
  // Use existing AuthInterceptor for token injection
}
```

### Repository to Create

```dart
// lib/features/driver/data/repositories/driver_repository.dart

abstract class IDriverRepository {
  // Profile
  Future<DriverProfile> getProfile();
  Future<DriverProfile> updateProfile(DriverProfile profile);
  
  // Status
  Future<void> updateStatus(DriverStatusRequest request);
  
  // Location
  Future<void> updateLocation(DriverLocationUpdate location);
  
  // Trips
  Future<void> acceptTrip(int tripId);
  Future<void> rejectTrip(int tripId);
  Future<void> arriveAtPickup(int tripId);
  Future<void> startTrip(int tripId);
  Future<void> completeTrip(int tripId);
  
  // Earnings
  Future<DriverEarnings> getEarnings();
  
  // History
  Future<TripsListResponse> getTripHistory(int page, int perPage);
}

class DriverRepository implements IDriverRepository {
  final IDriverDataSource _dataSource;
  
  // Implement with business logic and error handling
}
```

---

## STATE MANAGEMENT (Riverpod)

### Providers to Create

```dart
// lib/features/driver/presentation/providers/driver_providers.dart

// DataSource & Repository
final driverDataSourceProvider = Provider<IDriverDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DriverDataSource(apiClient);
});

final driverRepositoryProvider = Provider<IDriverRepository>((ref) {
  final dataSource = ref.watch(driverDataSourceProvider);
  return DriverRepository(dataSource);
});

// Profile
final driverProfileProvider = FutureProvider<DriverProfile>((ref) async {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getProfile();
});

// Status
final driverStatusProvider = StateNotifierProvider<DriverStatusNotifier, DriverStatus>((ref) {
  return DriverStatusNotifier(ref.watch(driverRepositoryProvider));
});

// Location Service
final driverLocationServiceProvider = Provider<DriverLocationService>((ref) {
  return DriverLocationService(
    ref.watch(driverRepositoryProvider),
    ref.watch(rtdbServiceProvider),
  );
});

// Incoming Trip Request (RTDB)
final incomingTripRequestProvider = StreamProvider<TripRequest?>((ref) {
  final rtdbService = ref.watch(rtdbServiceProvider);
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return const Stream.empty();
  return rtdbService.listenToTripRequest(userId.toString());
});

// Active Trip (RTDB)
final activeTripProvider = StreamProvider<TripData?>((ref) {
  final rtdbService = ref.watch(rtdbServiceProvider);
  final tripId = ref.watch(currentTripIdProvider);
  if (tripId == null) return const Stream.empty();
  return rtdbService.listenToTripStatus(tripId);
});

// Earnings
final driverEarningsProvider = FutureProvider<DriverEarnings>((ref) async {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getEarnings();
});

// Trip History
final driverTripHistoryProvider = FutureProvider.family<TripsListResponse, int>((ref, page) async {
  final repository = ref.watch(driverRepositoryProvider);
  return repository.getTripHistory(page, 20);
});
```

---

## RTDB INTEGRATION

### Extend RTDBService

```dart
// lib/core/services/rtdb_service.dart (extend existing)

// Add driver-specific methods
Stream<TripRequest?> listenToTripRequest(String driverId) {
  return _database
      .ref('drivers_online/$driverId/assigned_trip')
      .onValue
      .map((event) => event.snapshot.value != null 
          ? TripRequest.fromJson(event.snapshot.value as Map<String, dynamic>)
          : null);
}

Stream<DriverLocation?> listenToDriverLocation(String driverId) {
  return _database
      .ref('driver_locations/$driverId')
      .onValue
      .map((event) => event.snapshot.value != null
          ? DriverLocation.fromJson(event.snapshot.value as Map<String, dynamic>)
          : null);
}

Future<void> updateDriverOnlineStatus(String driverId, bool isOnline, {double? lat, double? lng}) {
  if (isOnline) {
    return _database.ref('drivers_online/$driverId').set({
      'status': 'online',
      'lat': lat,
      'lng': lng,
      'last_ping': ServerValue.timestamp,
    });
  } else {
    return _database.ref('drivers_online/$driverId').remove();
  }
}

Future<void> updateDriverLocation(String driverId, double lat, double lng, double heading, double speed) {
  return _database.ref('driver_locations/$driverId').set({
    'lat': lat,
    'lng': lng,
    'heading': heading,
    'speed': speed,
    'updated_at': ServerValue.timestamp,
  });
}
```

---

## FILE STRUCTURE

### Create the following files:

```
lib/features/driver/
├── data/
│   ├── models/
│   │   └── driver_models.dart
│   ├── datasources/
│   │   └── driver_datasource.dart
│   └── repositories/
│       └── driver_repository.dart
├── presentation/
│   ├── providers/
│   │   └── driver_providers.dart
│   ├── pages/
│   │   ├── driver_dashboard_page.dart
│   │   ├── incoming_trip_request_page.dart
│   │   ├── driver_trip_workflow_page.dart
│   │   ├── earnings_dashboard_page.dart
│   │   ├── driver_trip_history_page.dart
│   │   └── driver_profile_page.dart
│   └── widgets/
│       ├── driver_status_card.dart
│       ├── trip_request_card.dart
│       ├── earnings_card.dart
│       └── trip_history_item.dart
└── services/
    └── driver_location_service.dart
```

---

## NAVIGATION FLOW

### Driver App Flow:

```
main.dart (LoginPage)
    ↓
[Login as Driver]
    ↓
DriverDashboardPage
    ↓
[Toggle Online]
    ↓
[Wait for trip requests]
    ↓
IncomingTripRequestPage (via RTDB listener)
    ↓
[Accept Trip]
    ↓
DriverTripWorkflowPage
    ↓
[State transitions: ACCEPTED → ARRIVED → STARTED → COMPLETED]
    ↓
[Complete Trip]
    ↓
DriverDashboardPage (back to waiting)
    ↓
[View Earnings]
    ↓
EarningsDashboardPage
    ↓
[View History]
    ↓
DriverTripHistoryPage
    ↓
[View Profile]
    ↓
DriverProfilePage
```

---

## ERROR HANDLING

### Use existing error infrastructure from Phases 1-3:

- ✅ ErrorDialog for generic errors
- ✅ ValidationErrorDialog for validation errors
- ✅ SuccessDialog for confirmations
- ✅ NetworkErrorWidget for connectivity issues
- ✅ EmptyStateWidget for no data states

### Add driver-specific error handling:

```dart
// lib/features/driver/data/datasources/driver_datasource.dart

// Handle specific error cases:
- Location permission denied
- Background service not started
- Trip already accepted by another driver
- Trip expired
- Driver already on active trip
- Invalid status transition
```

---

## TESTING REQUIREMENTS

### Unit Tests:

```dart
// test/features/diver/data/datasources/driver_datasource_test.dart
- Test all API calls
- Test error handling
- Test request/response parsing

// test/features/driver/data/repositories/driver_repository_test.dart
- Test business logic
- Test error transformation
- Test state management

// test/features/driver/presentation/providers/driver_providers_test.dart
- Test all providers
- Test state transitions
- Test error states
```

### Widget Tests:

```dart
// test/features/driver/presentation/pages/driver_dashboard_page_test.dart
- Test dashboard rendering
- Test status toggle
- Test navigation

// test/features/driver/presentation/pages/incoming_trip_request_page_test.dart
- Test trip request display
- Test accept/reject buttons
- Test auto-reject timer
```

### Integration Tests:

```dart
// test/integration/driver_flow_test.dart
- Test complete driver flow
- Test RTDB integration
- Test background location service
```

---

## IMPLEMENTATION CHECKLIST

### Phase 4.1: Data Layer
- [ ] Create driver_models.dart with all DTOs
- [ ] Create IDriverDataSource interface
- [ ] Implement DriverDataSource with all API calls
- [ ] Create IDriverRepository interface
- [ ] Implement DriverRepository with business logic
- [ ] Add JSON serialization (run build_runner)

### Phase 4.2: State Management
- [ ] Create driver_providers.dart
- [ ] Implement all Riverpod providers
- [ ] Create DriverStatusNotifier
- [ ] Create currentTripIdProvider
- [ ] Test provider state transitions

### Phase 4.3: RTDB Integration
- [ ] Extend RTDBService with driver methods
- [ ] Implement listenToTripRequest
- [ ] Implement listenToDriverLocation
- [ ] Implement updateDriverOnlineStatus
- [ ] Implement updateDriverLocation
- [ ] Test RTDB streams

### Phase 4.4: Background Services
- [ ] Create DriverLocationService
- [ ] Implement background location tracking
- [ ] Implement periodic API calls
- [ ] Implement RTDB location updates
- [ ] Configure flutter_background_service
- [ ] Test background service

### Phase 4.5: UI Screens
- [ ] Create DriverDashboardPage
- [ ] Create IncomingTripRequestPage
- [ ] Create DriverTripWorkflowPage
- [ ] Create EarningsDashboardPage
- [ ] Create DriverTripHistoryPage
- [ ] Create DriverProfilePage
- [ ] Create supporting widgets

### Phase 4.6: Navigation
- [ ] Add driver routes to main.dart
- [ ] Implement navigation flow
- [ ] Add role-based routing
- [ ] Test navigation transitions

### Phase 4.7: Error Handling
- [ ] Add driver-specific error dialogs
- [ ] Implement error recovery
- [ ] Add network error handling
- [ ] Add validation error handling
- [ ] Test error scenarios

### Phase 4.8: Testing
- [ ] Write unit tests for data layer
- [ ] Write unit tests for providers
- [ ] Write widget tests for screens
- [ ] Write integration tests for flows
- [ ] Run all tests
- [ ] Fix any failing tests

### Phase 4.9: Code Quality
- [ ] Run flutter analyze
- [ ] Fix all analyzer issues
- [ ] Add documentation comments
- [ ] Format code with dart format
- [ ] Review code for best practices

### Phase 4.10: Final Verification
- [ ] Test complete driver flow end-to-end
- [ ] Verify RTDB integration
- [ ] Verify API integration
- [ ] Test background location service
- [ ] Test error scenarios
- [ ] Test on device/emulator
- [ ] Create PHASE_4_COMPLETE.md

---

## API CONTRACTS REFERENCE

### Authentication (Shared)
```
POST /api/v1/auth/mobile/login
Request: { phone, password, device_name, fcm_token }
Response: { token, user: { id, name, phone, role } }
```

### Driver Status
```
POST /api/v1/mobile/drivers/status
Request: { status, lat, lng }
Response: { success, message }
```

### Driver Location
```
POST /api/v1/mobile/drivers/live-location
Request: { lat, lng, heading, speed }
Response: { success }
```

### Trip Operations
```
POST /api/v1/mobile/drivers/trips/{id}/accept
Response: { success, data: { trip_id, status, passenger } }

POST /api/v1/mobile/drivers/trips/{id}/reject
Response: { success, message }

POST /api/v1/driver/motor-vehicle/trip-requests/{id}/arrived
Response: { success, data: { trip_id, status } }

PUT /api/v1/mobile/drivers/trips/{id}/start
Response: { success, data: { trip_id, status, started_at } }

PUT /api/v1/mobile/drivers/trips/{id}/complete
Response: { success, data: { trip_id, status, completed_at, fare, currency } }
```

### Earnings
```
GET /api/v1/driver/earnings
Response: { success, data: { today, week, month, recent_trips } }
```

### Profile
```
GET /api/v1/mobile/drivers/profile
Response: { success, data: { driver profile } }

PUT /api/v1/mobile/drivers/profile
Request: { name, phone, vehicle_plate, vehicle_type, vehicle_color }
Response: { success, data: { updated profile } }
```

### Trip History
```
GET /api/v1/mobile/drivers/trips/history?page=1&per_page=20
Response: { success, data: { trips, pagination } }
```

---

## RTDB DATA STRUCTURES

### drivers_online/{driver_id}
```json
{
  "status": "online",
  "lat": -1.9546,
  "lng": 30.0934,
  "last_ping": 1705324800000
}
```

### driver_locations/{driver_id}
```json
{
  "lat": -1.9548,
  "lng": 30.0938,
  "heading": 120.5,
  "speed": 15.2,
  "updated_at": 1705324800000
}
```

### drivers_online/{driver_id}/assigned_trip
```json
{
  "trip_id": 105,
  "passenger": {
    "name": "John Doe",
    "phone": "+250780000000",
    "rating": 4.8
  },
  "pickup_location": "Kigali Heights",
  "pickup_lat": -1.9546,
  "pickup_lng": 30.0934,
  "dropoff_location": "Kigali Convention Centre",
  "dropoff_lat": -1.9543,
  "dropoff_lng": 30.0967,
  "estimated_fare": 1500,
  "distance": "3.2 km",
  "duration": "8 mins",
  "vehicle_type": "motorcycle"
}
```

### active_trips/{trip_id}
```json
{
  "trip_id": 105,
  "status": "ACCEPTED",
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
```

### trip_tracking/{trip_id}
```json
{
  "driver_id": 42,
  "lat": -1.9548,
  "lng": 30.0938,
  "heading": 120.5,
  "speed": 15.2,
  "updated_at": 1705324800000
}
```

---

## IMPORTANT NOTES

### Dependencies Already Available
- ✅ firebase_database: ^11.3.10
- ✅ flutter_background_service: ^5.1.0
- ✅ geolocator: ^13.0.2
- ✅ dio: ^5.7.0
- ✅ riverpod: ^2.4.0
- ✅ flutter_secure_storage: ^9.2.2

### Services Already Implemented (Reuse)
- ✅ RTDBService (lib/core/services/rtdb_service.dart)
- ✅ ApiClient (lib/core/api/api_client.dart)
- ✅ AuthInterceptor (lib/core/api/auth_interceptor.dart)
- ✅ SecureStorageService (lib/core/storage/secure_storage_service.dart)
- ✅ ErrorHandler (lib/core/errors/error_handler.dart)

### Architecture Patterns to Follow
- ✅ Clean Architecture (already established)
- ✅ Repository Pattern (already established)
- ✅ Riverpod State Management (already established)
- ✅ Separation of Concerns (already established)

### Code Style
- Follow existing code style in the project
- Use Google Fonts for typography
- Use Material 3 design system
- Add comprehensive documentation comments
- Use meaningful variable names
- Keep functions focused and small

---

## SUCCESS CRITERIA

Phase 4 is complete when:

1. ✅ All driver data models created with JSON serialization
2. ✅ All driver API endpoints integrated in DataSource
3. ✅ All driver business logic implemented in Repository
4. ✅ All Riverpod providers created and tested
5. ✅ RTDB integration working for all driver operations
6. ✅ Background location service operational
7. ✅ All 6 driver screens implemented and navigable
8. ✅ Complete driver flow tested end-to-end
9. ✅ Error handling comprehensive
10. ✅ Unit tests written and passing
11. ✅ Widget tests written and passing
12. ✅ Integration tests written and passing
13. ✅ Code analysis clean (flutter analyze)
14. ✅ PHASE_4_COMPLETE.md documentation created
15. ✅ No Firestore references in driver code
16. ✅ RTDB-only architecture verified

---

## NEXT PHASES (After Phase 4)

- **Phase 5:** Notifications & Emergency Module
- **Phase 6:** Public Bus Module (Passenger)
- **Phase 7:** Error Handling & UX Polish
- **Phase 8:** Code Quality & Architecture Review
- **Phase 9:** Comprehensive Testing
- **Phase 10:** Production Deployment

---

**Generated:** 2024-06-16
**Status:** READY FOR IMPLEMENTATION
**Priority:** HIGH
**Estimated Duration:** 3-4 days
**Dependencies:** Phases 1-3 Complete ✅
