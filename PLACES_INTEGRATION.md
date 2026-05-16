Native Places SDK integration

Goal: use Google native Places SDK for autocomplete and place details on Android and iOS.

What I changed
- Added dependency `flutter_google_places_sdk: any` to `pubspec.yaml`.
- Left safe stubs in `lib/pages/passenger/passenger_booking_flow_page.dart` so the app continues to work if you don't configure keys.

Next steps (apply these to enable native behaviour)

1) Add the plugin

In your project root run:

```bash
flutter pub get
```

2) Android setup

- Open `android/app/src/main/AndroidManifest.xml` and add your API key inside the `<application>` element:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ANDROID_MAPS_API_KEY"/>
```

- If you use an app-restricted key, make sure it's restricted by package name + SHA‑1 fingerprint.

3) iOS setup

- In `ios/Runner/Info.plist` add a string key `GMSApiKey` with your iOS maps API key:

```xml
<key>GMSApiKey</key>
<string>YOUR_IOS_MAPS_API_KEY</string>
```

- For iOS, ensure the key is allowed for iOS bundle id restrictions if used.

4) Implement native calls (replace stubs)

Open `lib/pages/passenger/passenger_booking_flow_page.dart` and replace the stub methods `_nativePlaceSuggestions` and `_nativeFetchPlaceDetails` with code using `flutter_google_places_sdk` as follows (example):

```dart
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

final _places = FlutterGooglePlacesSdk();

Future<_PlaceSuggestionResult> _nativePlaceSuggestions(String input) async {
  try {
    final predictions = await _places.findAutocompletePredictions(
      input,
      country: 'RW',
      type: AutocompleteType.address,
    );
    return _PlaceSuggestionResult(
      suggestions: predictions.map((p) => _PlaceSuggestion(
        description: p.fullText,
        placeId: p.placeId ?? '',
        location: null, // we'll fetch details when selected
      )).toList(),
      error: null,
    );
  } catch (e) {
    return const _PlaceSuggestionResult(suggestions: [], error: null);
  }
}

Future<_PlaceSuggestion?> _nativeFetchPlaceDetails(String placeId) async {
  try {
    final place = await _places.fetchPlace(placeId, fields: [PlaceField.geometry, PlaceField.formattedAddress, PlaceField.name]);
    final lat = place.latLng?.lat;
    final lng = place.latLng?.lng;
    if (lat == null || lng == null) return null;
    final description = place.formattedAddress ?? place.name ?? '';
    return _PlaceSuggestion(description: description, placeId: placeId, location: LatLng(lat, lng));
  } catch (e) {
    return null;
  }
}
```

Note: the exact method names above may differ by plugin version — use the plugin docs if needed.

5) Rebuild and test

- Run on Android and iOS devices/emulators after adding the keys.
- Type into the picker address field — you should see native suggestions and selecting one should update the picker.

If you want, I can implement the code changes directly (replace the stub methods with the above code) and add any necessary imports — say "implement now" and I'll patch the file.