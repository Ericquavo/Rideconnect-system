# Firestore Removal Checklist & File Cleanup

**Objective:** Identify and remove all Firestore dependencies before RTDB-only migration

---

## Step 1: Search for Firestore Artifacts

### 1.1 Imports to Remove
Search for and remove these patterns:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Remove:
FirebaseFirestore.instance
CollectionReference
DocumentReference
DocumentSnapshot
QuerySnapshot
Query
WriteBatch
```

### 1.2 Services to Delete
Look for and DELETE these files entirely:

- `lib/services/firestore_repository.dart`
- `lib/services/firestore_trip_tracker.dart`
- `lib/services/firestore_presence_manager.dart`
- `lib/services/firestore_realtime_service.dart`
- `lib/features/trips/services/firestore_*`
- `lib/features/driver/services/firestore_*`
- Any file with "firestore" in the name

### 1.3 Providers to Delete/Update
Search for Firestore-based providers:

```dart
// Remove these patterns:
final firestoreProvider = Provider((ref) => ...);
final tripListenerProvider = StreamProvider((ref) => 
  FirebaseFirestore.instance.collection('trips').snapshots()
);
final driverLocationProvider = StreamProvider((ref) =>
  FirebaseFirestore.instance.collection('drivers').snapshots()
);
```

---

## Step 2: pubspec.yaml Cleanup

### Current Dependencies to REMOVE:
```yaml
cloud_firestore: ^4.14.0  # REMOVE THIS
firebase_firestore: ^4.x  # REMOVE IF EXISTS
```

### Verify These Are KEPT:
```yaml
firebase_core: ^2.x
firebase_database: ^10.x          # KEEP - this is RTDB
firebase_messaging: ^14.x
flutter_riverpod: ^2.x
dio: ^5.x
geolocator: ^9.x
google_maps_flutter: ^2.x
```

**After removal, run:**
```bash
flutter pub get
flutter pub clean
```

---

## Step 3: Code Search & Replace

### 3.1 Find All Firestore References

Run these searches:

```bash
# Search for Firestore imports
grep -r "cloud_firestore" lib/

# Search for FirebaseFirestore usage
grep -r "FirebaseFirestore\.instance" lib/

# Search for CollectionReference
grep -r "CollectionReference" lib/

# Search for DocumentReference
grep -r "DocumentReference" lib/

# Search for Firestore listeners
grep -r "\.snapshots()" lib/
grep -r "\.onSnapshot" lib/
```

### 3.2 Files Likely Containing Firestore

Search these directories:
- `lib/services/`
- `lib/features/trips/services/`
- `lib/features/driver/services/`
- `lib/providers/`
- `lib/realtime/`

---

## Step 4: File-by-File Removal Checklist

Go through these locations and DELETE matching files:

### Services Directory
```
lib/services/
├── [ ] firestore_*.dart - DELETE ALL
├── [ ] *_firestore.dart - DELETE
├── [ ] realtime/ - CHECK FOR FIRESTORE
└── [ ] matching/ - CHECK FOR FIRESTORE
```

### Features Directory
```
lib/features/
├── trips/
│   └── services/
│       ├── [ ] firestore_trip_listener.dart - DELETE
│       ├── [ ] firestore_sync.dart - DELETE
│       ├── [ ] trip_lifecycle_manager.dart - KEEP BUT REFACTOR
│       └── [ ] *_firestore.dart - DELETE ALL
├── driver/
│   └── services/
│       ├── [ ] firestore_presence.dart - DELETE
│       ├── [ ] firestore_location_tracker.dart - DELETE
│       └── [ ] *_firestore.dart - DELETE ALL
└── passenger/
    └── services/
        ├── [ ] firestore_*.dart - DELETE ALL
```

### Models Directory
```
lib/models/
├── [ ] firestore_model.dart - DELETE IF EXISTS
├── [ ] *firestore*.dart - DELETE ALL
└── matching/
    └── [ ] *firestore*.dart - DELETE ALL
```

### Providers Directory
```
lib/providers/
├── [ ] firestore_*_provider.dart - DELETE
├── [ ] *_firestore_provider.dart - DELETE ALL
└── Search for StreamProvider with .snapshots()
    └── [ ] REPLACE with RTDB listeners
```

---

## Step 5: Code Refactoring

### 5.1 TripLifecycleManager Refactor (CRITICAL)

**Current Implementation (Remove):**
```dart
// lib/features/trips/services/trip_lifecycle_manager.dart

Timer? _pollTimer;

void startPolling(int tripId) {
  _pollTimer = Timer.periodic(Duration(seconds: 5), (timer) {
    _pollTrip(tripId);  // GET /trip-requests/{id}
  });
}
```

**New Implementation (Replace with):**
```dart
StreamSubscription? _tripListener;

void startListening(int tripId) {
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

@override
void dispose() {
  _tripListener?.cancel();
}
```

### 5.2 Driver Location Tracking

**Remove Firestore listener:**
```dart
// REMOVE THIS:
FirebaseFirestore.instance
  .collection('driver_locations')
  .where('driver_id', isEqualTo: driverId)
  .snapshots()
  .listen((snapshot) { ... });
```

**Replace with RTDB:**
```dart
// ADD THIS:
FirebaseDatabase.instance
  .ref('driver_locations/$driverId')
  .onValue
  .listen((event) {
    if (event.snapshot.exists) {
      _updateDriverLocation(event.snapshot.value);
    }
  });
```

### 5.3 Presence/Availability Tracking

**Remove Firestore:**
```dart
// REMOVE:
FirebaseFirestore.instance.collection('presence').doc(userId)
  .update({'online': true, 'last_seen': FieldValue.serverTimestamp()})
```

**Replace with RTDB:**
```dart
// ADD:
FirebaseDatabase.instance.ref('presence/$userId').set({
  'online': true,
  'last_seen': ServerValue.timestamp,
});
```

---

## Step 6: Provider Cleanup

### 6.1 Remove Firestore Providers
```bash
# Find all StreamProvider definitions
grep -n "StreamProvider" lib/providers/*.dart

# Look for patterns like:
# final tripProvider = StreamProvider((ref) => 
#   FirebaseFirestore.instance.collection('trips').snapshots()
# );

# REPLACE with Riverpod notifiers using RTDB listeners
```

### 6.2 Create New RTDB Providers
```dart
// lib/providers/rtdb_providers.dart

final tripListenerProvider = StreamProvider.autoDispose<Trip>((ref) {
  final tripId = ref.watch(currentTripIdProvider);
  if (tripId == null) throw Exception('No active trip');
  
  return FirebaseDatabase.instance
    .ref('active_trips/$tripId')
    .onValue
    .map((event) => Trip.fromJson(event.snapshot.value));
});

final driverLocationProvider = 
    StreamProvider.family.autoDispose<DriverLocation, String>(
  (ref, driverId) {
    return FirebaseDatabase.instance
      .ref('driver_locations/$driverId')
      .onValue
      .map((event) => DriverLocation.fromJson(event.snapshot.value));
  },
);
```

---

## Step 7: Dependency Cleanup

### 7.1 Remove Firestore from DI

**Check these files:**
- `lib/main.dart` - Remove Firestore initialization
- `lib/core/di/` or similar - Remove Firestore providers
- `lib/providers/api_providers.dart` - Remove Firestore references

**Firestore initialization to REMOVE:**
```dart
// main.dart - REMOVE:
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
);
```

**Keep only:**
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
FirebaseDatabase.instance.setPersistenceEnabled(true);
```

### 7.2 Remove Firestore from Android/iOS

**Android (android/build.gradle.kts):**
```kotlin
// Remove any Firestore-specific rules
```

**iOS (ios/Podfile):**
```ruby
# Remove Firestore pod if explicitly listed
```

---

## Step 8: Validation

### 8.1 Compile & Build Check
```bash
flutter clean
flutter pub get
flutter pub cache clean
flutter analyze
flutter build apk --analyze-size
```

### 8.2 Search Validation

After cleanup, run these to verify NO Firestore remains:

```bash
# Should return ZERO results:
grep -r "cloud_firestore" lib/
grep -r "FirebaseFirestore\." lib/
grep -r "CollectionReference" lib/
grep -r "DocumentReference" lib/
grep -r "WriteBatch" lib/
grep -r "\.snapshots()" lib/ | grep -v rtdb  # Should only show RTDB

# Should find RTDB usage:
grep -r "FirebaseDatabase.instance.ref" lib/
grep -r "onValue.listen" lib/
```

### 8.3 Runtime Validation

When app starts:
```
✓ No "Could not find plugin" errors for cloud_firestore
✓ No Firestore initialization errors
✓ RTDB listeners activate correctly
✓ Location updates through RTDB work
✓ Trip status updates through RTDB work
```

---

## Step 9: Migration Summary

### What's Deleted
- ❌ All Firestore-based services
- ❌ All Firestore listeners
- ❌ All Firestore repositories
- ❌ `cloud_firestore` package
- ❌ Firestore imports
- ❌ Firestore initialization code

### What's Replaced
- ✅ Firestore listeners → RTDB listeners
- ✅ Firestore collections → RTDB paths
- ✅ Firestore document updates → RTDB set/update
- ✅ Firestore transactions → RTDB transactions
- ✅ Firestore presence → RTDB presence node

### What's Added
- ✅ RTDBService for centralized access
- ✅ RTDB stream providers
- ✅ RTDB listener cleanup
- ✅ Connection state handling
- ✅ Offline fallback to API

---

## Final Checklist

- [ ] Searched entire codebase for Firestore
- [ ] Removed all Firestore imports
- [ ] Deleted all Firestore services
- [ ] Updated pubspec.yaml (removed cloud_firestore)
- [ ] Refactored TripLifecycleManager (removed polling)
- [ ] Created RTDB listeners
- [ ] Updated providers to use RTDB
- [ ] Removed Firestore initialization from main.dart
- [ ] Ran `flutter analyze` - ZERO Firestore errors
- [ ] Ran `flutter build` - Successful
- [ ] Tested app on device - No Firestore errors
- [ ] Verified RTDB listeners work
- [ ] Verified API fallbacks work

---

## Commands to Run

```bash
# Step 1: Remove dependency
flutter pub remove cloud_firestore

# Step 2: Clean and refresh
flutter clean
flutter pub get

# Step 3: Analyze
flutter analyze

# Step 4: Build
flutter build apk

# Step 5: Run
flutter run

# Step 6: Verify
adb logcat | grep -i firestore  # Should show NOTHING
adb logcat | grep -i rtdb       # Should show listeners connecting
```

---

This checklist ensures complete Firestore removal and RTDB-only architecture!
