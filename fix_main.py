import re

with open('lib/main.dart', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# Find _onGenerateRoute up to the first corrupted part
match = re.search(r'(Route<dynamic>\? _onGenerateRoute\(RouteSettings settings\) \{.*?return _slide\(const MotorcycleRequestScreen\(\), settings\);\s*\})', content, re.DOTALL)
if match:
    good_part = match.group(1)
    
    # We will reconstruct the remaining routes
    rest = """

  // /trip/searching/:id
  if (segments.length == 3 && segments[0] == 'trip' && segments[1] == 'searching') {
    final id = extractId(2);
    if (id != null) {
      return _slide(SearchingDriverScreen(tripId: id), settings);
    }
  }

  // /trips/:id
  if (segments.length == 2 && segments[0] == 'trips') {
    final id = extractId(1, 'tripId');
    if (id != null) {
      return _slide(TripDetailsScreen(tripId: id), settings);
    }
  }

  // /trip/track/:id
  if (segments.length == 3 && segments[0] == 'trip' && segments[1] == 'track') {
    final id = extractId(2);
    if (id != null) {
      return _slide(TripTrackingScreen(tripId: id), settings);
    }
  }

  // /trip/map/:id
  if (segments.length == 3 && segments[0] == 'trip' && segments[1] == 'map') {
    final id = extractId(2);
    if (id != null) {
      final args = getArgs();
      return _slide(
        LiveDriverMapScreen(
          tripId: id,
          isMotorVehicle: args?['isMotorVehicle'] as bool? ?? true,
        ),
        settings,
      );
    }
  }

  // /trip/rate/:id
  if (segments.length == 3 && segments[0] == 'trip' && segments[1] == 'rate') {
    final id = extractId(2);
    if (id != null) {
      final args = getArgs();
      return _slide(
        RateDriverScreen(
          tripId: id,
          isMotorVehicle: args?['isMotorVehicle'] as bool? ?? true,
        ),
        settings,
      );
    }
  }

  // /driver/navigate/:id
  if (segments.length == 3 && segments[0] == 'driver' && segments[1] == 'navigate') {
    final id = extractId(2);
    if (id != null) {
      final args = getArgs();
      return _slide(
        DriverNavigationScreen(
          tripId: id,
          passengerLat: (args?['passengerLat'] as num?)?.toDouble(),
          passengerLng: (args?['passengerLng'] as num?)?.toDouble(),
          dropoffLat: (args?['dropoffLat'] as num?)?.toDouble(),
          dropoffLng: (args?['dropoffLng'] as num?)?.toDouble(),
          passengerName: args?['passengerName']?.toString() ?? 'Passenger',
          passengerPhone: args?['passengerPhone']?.toString() ?? '',
          pickupAddress: args?['pickupAddress']?.toString() ?? 'Pickup',
          dropoffAddress: args?['dropoffAddress']?.toString() ?? 'Dropoff',
          estimatedFare: (args?['estimatedFare'] as num?)?.toDouble(),
        ),
        settings,
      );
    }
  }

  return null; // falls back to 404/unknown route
}

/// Slide-in page transition (right-to-left).
PageRouteBuilder<dynamic> _slide(Widget page, RouteSettings settings) {
  return PageRouteBuilder<dynamic>(
    settings: settings,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
  );
}
"""
    
    # Replace the whole Route<dynamic>? _onGenerateRoute... up to EOF with our fixed version
    new_content = re.sub(r'Route<dynamic>\? _onGenerateRoute\(RouteSettings settings\) \{.*', good_part + rest, content, flags=re.DOTALL)
    
    with open('lib/main.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Fixed main.dart")
else:
    print("Could not match")
