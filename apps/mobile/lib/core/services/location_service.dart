import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a GPS capture. [error] is set (and coordinates null) on failure.
class LocationFix {
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? street;
  final String? city;
  final String? state;
  final String? pincode;
  final String? error;
  /// True when the user must change a setting (location off / permanently denied).
  final bool needsSettings;

  const LocationFix({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.street,
    this.city,
    this.state,
    this.pincode,
    this.error,
    this.needsSettings = false,
  });

  bool get ok => error == null && latitude != null && longitude != null;
}

/// Real device GPS: permission handling, current position and (on Android /
/// iOS) reverse geocoding into street / city / state / pincode.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<LocationFix> captureCurrentLocation({bool resolveAddress = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFix(
          error: 'Location is turned off. Please switch on GPS / Location and try again.',
          needsSettings: true,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationFix(error: 'Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationFix(
          error: 'Location permission is blocked. Allow it in App Settings to tag GPS.',
          needsSettings: true,
        );
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        // Weak indoor signal: fall back to the last known fix if there is one.
        final last = kIsWeb ? null : await Geolocator.getLastKnownPosition();
        if (last == null) {
          return const LocationFix(error: 'Could not get a GPS fix. Move to an open area and try again.');
        }
        position = last;
      }

      String? street, city, state, pincode;
      // The geocoding plugin supports Android / iOS only.
      if (resolveAddress && !kIsWeb) {
        try {
          final marks = await Geocoding()
              .placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(const Duration(seconds: 10));
          if (marks.isNotEmpty) {
            final m = marks.first;
            String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
            street = [clean(m.name), clean(m.street), clean(m.subLocality)]
                .whereType<String>()
                .toSet() // name and street are often identical
                .join(', ');
            if (street.isEmpty) street = null;
            city = clean(m.locality) ?? clean(m.subAdministrativeArea);
            state = clean(m.administrativeArea);
            pincode = clean(m.postalCode);
          }
        } catch (e) {
          debugPrint('LocationService: reverse geocoding failed: $e');
        }
      }

      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        street: street,
        city: city,
        state: state,
        pincode: pincode,
      );
    } catch (e) {
      return LocationFix(error: 'Location error: $e');
    }
  }

  /// Opens Location settings if GPS is off, otherwise this app's settings.
  Future<void> openSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
