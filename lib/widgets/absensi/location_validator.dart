import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '/core/services/overtime_history_service.dart';

class LocationValidator {
  
  
  static const double defaultRadiusOffice = 100.0;
  
  static const double defaultRadiusProject = 300.0;
  
  /// 🔥 BATAS MAKSIMUM RADIUS YANG DIIZINKAN (2000 meter = 2km)
  /// Mencegah radius terlalu besar yang disalahgunakan
  static const double maximumAllowedRadius = 2000.0;
  
  /// 🔥 BATAS MINIMUM RADIUS (10 meter)
  static const double minimumAllowedRadius = 10.0;
  
  static const LocationAccuracy defaultAccuracy = LocationAccuracy.high;
  static const int locationTimeoutSeconds = 30;
  static const int geocodingTimeoutSeconds = 10;
  static const int maxLocationRetries = 2;

  // 🔥 LAZY INIT - Hindari crash saat konstruksi
  geocoding.Geocoding? _geocoder;
  bool _geocoderInitAttempted = false;

  // Cache untuk address
  final Map<String, String> _addressCache = {};

  // ===========================================================================
  // SAFE GEOCODER GETTER
  // ===========================================================================

  /// 🔥 Getter aman untuk Geocoding instance
  geocoding.Geocoding get _safeGeocoder {
    if (_geocoder != null) return _geocoder!;
    
    if (_geocoderInitAttempted) {
      debugPrint('📍 LocationValidator: Retrying Geocoding init...');
    }
    
    try {
      _geocoder = geocoding.Geocoding();
      _geocoderInitAttempted = true;
      debugPrint('📍 LocationValidator: Geocoding initialized successfully');
      return _geocoder!;
    } catch (e, stackTrace) {
      _geocoderInitAttempted = true;
      debugPrint('=' * 80);
      debugPrint('📍 LocationValidator: CRITICAL - Failed to init Geocoding');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('=' * 80);
      
      throw Exception(
        'Gagal menginisialisasi layanan geocoding. '
        'Error: ${e.toString().split('\n').first}'
      );
    }
  }

  // ===========================================================================
  // LOCATION SERVICE & PERMISSION
  // ===========================================================================

  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('📍 LocationValidator: Service check timeout');
      return false;
    } catch (e) {
      debugPrint('📍 LocationValidator: Service check error: $e');
      return false;
    }
  }

  Future<LocationPermission> checkAndRequestPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 5));

      debugPrint('📍 LocationValidator: Current permission: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 20));

        debugPrint('📍 LocationValidator: After request: $permission');
      }

      return permission;
    } on TimeoutException {
      debugPrint('📍 LocationValidator: Permission check/request timeout');
      return LocationPermission.denied;
    } catch (e) {
      debugPrint('📍 LocationValidator: Permission check error: $e');
      return LocationPermission.denied;
    }
  }

  bool isPermissionGranted(LocationPermission permission) {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // ===========================================================================
  // LOCATION AVAILABILITY
  // ===========================================================================

  Future<Map<String, dynamic>> checkLocationAvailability() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();

      if (!serviceEnabled) {
        return {
          'available': false,
          'service_enabled': false,
          'permission_granted': false,
          'permission_status': 'unknown',
          'message': 'GPS/Location service belum aktif',
        };
      }

      final permission = await checkAndRequestPermission();
      final granted = isPermissionGranted(permission);

      return {
        'available': serviceEnabled && granted,
        'service_enabled': serviceEnabled,
        'permission_granted': granted,
        'permission_status': permission.toString(),
        'message': granted
            ? 'Lokasi tersedia'
            : permission == LocationPermission.deniedForever
                ? 'Izin lokasi ditolak permanen. Buka pengaturan aplikasi.'
                : 'Izin lokasi belum diberikan',
      };
    } catch (e) {
      debugPrint('📍 LocationValidator: Availability error: $e');
      return {
        'available': false,
        'service_enabled': false,
        'permission_granted': false,
        'permission_status': 'error',
        'message': 'Gagal memeriksa akses lokasi',
        'error': e.toString(),
      };
    }
  }

  // ===========================================================================
  // GET CURRENT LOCATION
  // ===========================================================================

  Future<Position?> getCurrentLocation({
    LocationAccuracy accuracy = defaultAccuracy,
    bool allowLastKnownFallback = true,
  }) async {
    try {
      final availability = await checkLocationAvailability();

      if (availability['available'] != true) {
        debugPrint(
          '📍 LocationValidator: Location unavailable - ${availability['message']}',
        );
        return allowLastKnownFallback ? await _getLastKnownPositionSafe() : null;
      }

      for (int attempt = 1; attempt <= maxLocationRetries; attempt++) {
        try {
          debugPrint(
            '📍 LocationValidator: Getting current location '
            '(attempt $attempt/$maxLocationRetries)',
          );

          final LocationSettings locationSettings;
          
          if (defaultTargetPlatform == TargetPlatform.android) {
            locationSettings = AndroidSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: locationTimeoutSeconds),
              distanceFilter: 0,
              forceLocationManager: true,
              intervalDuration: const Duration(seconds: 1),
            );
          } else if (defaultTargetPlatform == TargetPlatform.iOS || 
                     defaultTargetPlatform == TargetPlatform.macOS) {
            locationSettings = AppleSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: locationTimeoutSeconds),
              distanceFilter: 0,
              activityType: ActivityType.fitness,
              showBackgroundLocationIndicator: false,
            );
          } else if (kIsWeb) {
            locationSettings = WebSettings(
              accuracy: LocationAccuracy.high,
              maximumAge: Duration(seconds: 10),
            );
          } else {
            locationSettings = LocationSettings(
              accuracy: accuracy,
              timeLimit: Duration(seconds: locationTimeoutSeconds),
              distanceFilter: 0,
            );
          }

          final position = await Geolocator.getCurrentPosition(
            locationSettings: locationSettings,
          );

          if (_isValidCoordinate(position.latitude, position.longitude)) {
            debugPrint(
              '📍 LocationValidator: Current position OK - '
              '${position.latitude}, ${position.longitude}, '
              'accuracy: ${position.accuracy}m',
            );
            return position;
          }

          debugPrint('📍 LocationValidator: Invalid current position received');
        } on TimeoutException {
          debugPrint('📍 LocationValidator: getCurrentPosition timeout');
        } catch (e) {
          debugPrint('📍 LocationValidator: getCurrentPosition error: $e');
        }

        if (attempt < maxLocationRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      return allowLastKnownFallback ? await _getLastKnownPositionSafe() : null;
    } catch (e, stackTrace) {
      debugPrint('=' * 80);
      debugPrint('📍 LocationValidator: getCurrentLocation CRITICAL ERROR');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('=' * 80);

      return allowLastKnownFallback ? await _getLastKnownPositionSafe() : null;
    }
  }

  Future<Position?> _getLastKnownPositionSafe() async {
    try {
      debugPrint('📍 LocationValidator: Trying last known position...');

      final position = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 8));

      if (position == null) {
        debugPrint('📍 LocationValidator: Last known position is null');
        return null;
      }

      if (!_isValidCoordinate(position.latitude, position.longitude)) {
        debugPrint('📍 LocationValidator: Last known position invalid');
        return null;
      }

      debugPrint(
        '📍 LocationValidator: Last known position OK - '
        '${position.latitude}, ${position.longitude}',
      );

      return position;
    } catch (e) {
      debugPrint('📍 LocationValidator: Last known position failed: $e');
      return null;
    }
  }

  // ===========================================================================
  // ADDRESS FROM COORDINATES
  // ===========================================================================

  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final cacheKey = '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey];
    }

    if (kIsWeb) {
      debugPrint('📍 LocationValidator: Web platform - using fallback address');
      final fallback = _getFallbackAddress(latitude, longitude);
      _addressCache[cacheKey] = fallback;
      return fallback;
    }

    try {
      if (!_isValidCoordinate(latitude, longitude)) {
        debugPrint('📍 LocationValidator: Invalid coordinate for geocoding');
        return null;
      }

      debugPrint('📍 LocationValidator: Geocoding coordinates: $latitude, $longitude');

      try {
        final geocoder = _safeGeocoder;
        
        final List<geocoding.Placemark> placemarks = await geocoder
            .placemarkFromCoordinates(latitude, longitude)
            .timeout(const Duration(seconds: geocodingTimeoutSeconds));

        debugPrint('📍 LocationValidator: Geocoding result: ${placemarks.length} placemarks found');

        if (placemarks.isEmpty) {
          debugPrint('📍 LocationValidator: No placemarks found');
          final fallback = _getFallbackAddress(latitude, longitude);
          _addressCache[cacheKey] = fallback;
          return fallback;
        }

        final place = placemarks.first;
        
        final parts = <String>[];
        
        final street = _safeString(place.street);
        if (street.isNotEmpty) parts.add(street);
        
        final subLocality = _safeString(place.subLocality);
        if (subLocality.isNotEmpty) parts.add(subLocality);
        
        final locality = _safeString(place.locality);
        if (locality.isNotEmpty) parts.add(locality);
        
        final subAdminArea = _safeString(place.subAdministrativeArea);
        if (subAdminArea.isNotEmpty) parts.add(subAdminArea);
        
        final adminArea = _safeString(place.administrativeArea);
        if (adminArea.isNotEmpty) parts.add(adminArea);
        
        final country = _safeString(place.country);
        if (country.isNotEmpty) parts.add(country);

        if (parts.isEmpty) {
          debugPrint('📍 LocationValidator: All placemark fields are empty');
          final fallback = _getFallbackAddress(latitude, longitude);
          _addressCache[cacheKey] = fallback;
          return fallback;
        }

        final address = parts.join(', ');
        debugPrint('📍 LocationValidator: Address built: $address');
        
        _addressCache[cacheKey] = address;
        return address;
        
      } catch (geocodingError) {
        debugPrint('📍 LocationValidator: Geocoding error (inner): $geocodingError');
        final fallback = _getFallbackAddress(latitude, longitude);
        _addressCache[cacheKey] = fallback;
        return fallback;
      }
      
    } on TimeoutException {
      debugPrint('📍 LocationValidator: Geocoding timeout');
      final fallback = _getFallbackAddress(latitude, longitude);
      _addressCache[cacheKey] = fallback;
      return fallback;
    } catch (e, stacktrace) {
      debugPrint('📍 LocationValidator: Geocoding error: $e');
      debugPrint('📍 LocationValidator: Stacktrace: $stacktrace');
      final fallback = _getFallbackAddress(latitude, longitude);
      _addressCache[cacheKey] = fallback;
      return fallback;
    }
  }

  String _getFallbackAddress(double latitude, double longitude) {
    final latStr = latitude.toStringAsFixed(6);
    final lngStr = longitude.toStringAsFixed(6);
    return '📍 $latStr, $lngStr';
  }

  String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  // ===========================================================================
  // 🔥🔥🔥 VALIDATE LOCATION - ULTIMATE FIXED (RADIUS KETAT)
  // ===========================================================================

  Future<Map<String, dynamic>> validateLocation({
    required double currentLat,
    required double currentLng,
    required OvertimeHistory overtimeItem,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // 1️⃣ Validasi koordinat perangkat
      if (!_isValidCoordinate(currentLat, currentLng)) {
        return _failure(
          message: 'Koordinat perangkat tidak valid',
          errorCode: 'invalid_current_coordinate',
        );
      }

      // 2️⃣ Parse data lokasi dari overtime item
      final lokasi = _parseMapSafe(overtimeItem.lokasi);

      if (lokasi.isEmpty) {
        debugPrint('📍 LocationValidator: No location reference found - ALLOWING with warning');
        return _successNoReference();
      }

      // 3️⃣ Ambil koordinat target
      final targetLat = _parseDoubleSafe(lokasi['latitude']);
      final targetLng = _parseDoubleSafe(lokasi['longitude']);

      if (targetLat == null || targetLng == null) {
        debugPrint('📍 LocationValidator: Target coordinates not found - ALLOWING with warning');
        return _successNoReference();
      }

      if (!_isValidCoordinate(targetLat, targetLng)) {
        return _failure(
          message: 'Koordinat target absensi tidak valid',
          errorCode: 'invalid_target_coordinate',
        );
      }

      // 4️⃣ 🔥 DAPATKAN MAX RADIUS DENGAN VALIDASI KETAT
      final maxRadius = _getMaximumRadiusSafe(lokasi);
      final lokasiNama = _getLokasiNama(lokasi);
      final lokasiAlamat = _getLokasiAlamat(lokasi);

      // 🔥 LOG DETAIL LOKASI TARGET
      debugPrint('═══════════════════════════════════════');
      debugPrint('📍 VALIDASI LOKASI ABSENSI');
      debugPrint('   Target: $lokasiNama');
      debugPrint('   Alamat: $lokasiAlamat');
      debugPrint('   Koordinat Target: $targetLat, $targetLng');
      debugPrint('   Koordinat User: $currentLat, $currentLng');
      debugPrint('   Max Radius: ${formatDistance(maxRadius)}');
      debugPrint('═══════════════════════════════════════');

      // 5️⃣ Hitung jarak
      final distance = _safeDistanceBetween(
        currentLat,
        currentLng,
        targetLat,
        targetLng,
      );

      if (distance == null) {
        return _failure(
          message: 'Gagal menghitung jarak lokasi',
          errorCode: 'distance_calculation_failed',
        );
      }

      // 6️⃣ 🔥 VALIDASI FINAL
      final isValid = distance <= maxRadius;
      
      // 🔥 Log hasil
      debugPrint('📍 HASIL VALIDASI:');
      debugPrint('   Jarak: ${formatDistance(distance)}');
      debugPrint('   Batas: ${formatDistance(maxRadius)}');
      debugPrint('   Status: ${isValid ? "✅ VALID" : "❌ TIDAK VALID"}');
      debugPrint('   Selisih: ${formatDistance((distance - maxRadius).abs())} ${distance > maxRadius ? "di luar" : "di dalam"} batas');
      debugPrint('   Waktu: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('═══════════════════════════════════════');

      stopwatch.stop();

      return {
        'valid': isValid,
        'distance': distance,
        'distance_text': formatDistance(distance),
        'max_radius': maxRadius,
        'max_radius_text': formatDistance(maxRadius),
        'target_latitude': targetLat,
        'target_longitude': targetLng,
        'current_latitude': currentLat,
        'current_longitude': currentLng,
        'target_name': lokasiNama,
        'target_address': lokasiAlamat,
        'is_outside': !isValid,
        'margin': (distance - maxRadius).abs(),
        'margin_text': formatDistance((distance - maxRadius).abs()),
        'message': isValid
            ? '✅ Lokasi valid! Anda berada dalam radius absensi (${formatDistance(distance)} dari ${formatDistance(maxRadius)}).'
            : '❌ Anda berada di luar radius absensi! Jarak: ${formatDistance(distance)} (batas: ${formatDistance(maxRadius)}). '
              'Pindah ke lokasi yang lebih dekat dengan $lokasiNama.',
      };
    } catch (e, stackTrace) {
      debugPrint('=' * 80);
      debugPrint('📍 LocationValidator: validateLocation ERROR');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('=' * 80);

      stopwatch.stop();
      return _failure(
        message: 'Terjadi kesalahan saat validasi lokasi',
        errorCode: 'validation_exception',
        error: e.toString(),
      );
    }
  }

  /// 🔥 Ambil nama lokasi dari data
  String _getLokasiNama(Map<String, dynamic> lokasi) {
    return _safeString(
      lokasi['nama_lokasi'] ?? 
      lokasi['nama'] ?? 
      lokasi['name'] ?? 
      lokasi['alamat'] ??
      'Lokasi Proyek'
    );
  }

  /// 🔥 Ambil alamat lengkap dari data
  String _getLokasiAlamat(Map<String, dynamic> lokasi) {
    return _safeString(
      lokasi['alamat_lengkap'] ?? 
      lokasi['alamat'] ?? 
      lokasi['address'] ??
      _getLokasiNama(lokasi)
    );
  }

  Future<Map<String, dynamic>> validateCurrentLocation({
    required OvertimeHistory overtimeItem,
  }) async {
    final position = await getCurrentLocation();

    if (position == null) {
      return _failure(
        message:
            'Gagal mendapatkan lokasi perangkat. Pastikan GPS aktif dan izin lokasi diberikan.',
        errorCode: 'current_location_not_found',
      );
    }

    return validateLocation(
      currentLat: position.latitude,
      currentLng: position.longitude,
      overtimeItem: overtimeItem,
    );
  }

  // ===========================================================================
  // BATCH VALIDATION
  // ===========================================================================

  Future<bool> validateAnyLocation({
    required double currentLat,
    required double currentLng,
    required List<Map<String, dynamic>> targetLocations,
  }) async {
    if (!_isValidCoordinate(currentLat, currentLng)) return false;
    if (targetLocations.isEmpty) return true;

    for (final rawTarget in targetLocations) {
      final target = _parseMapSafe(rawTarget);
      if (target.isEmpty) continue;

      final targetLat = _parseDoubleSafe(target['latitude']);
      final targetLng = _parseDoubleSafe(target['longitude']);

      if (targetLat == null || targetLng == null) continue;
      if (!_isValidCoordinate(targetLat, targetLng)) continue;

      final maxRadius = _getMaximumRadiusSafe(target);

      final distance = _safeDistanceBetween(
        currentLat,
        currentLng,
        targetLat,
        targetLng,
      );

      if (distance == null) continue;

      if (distance <= maxRadius) {
        debugPrint(
          '📍 LocationValidator: Valid target found at ${formatDistance(distance)}',
        );
        return true;
      }
    }

    return false;
  }

  // ===========================================================================
  // OPEN SETTINGS
  // ===========================================================================

  Future<bool> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
      return true;
    } catch (e) {
      debugPrint('📍 LocationValidator: Cannot open location settings: $e');
      return false;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
      return true;
    } catch (e) {
      debugPrint('📍 LocationValidator: Cannot open app settings: $e');
      return false;
    }
  }

  // ===========================================================================
  // CACHE MANAGEMENT
  // ===========================================================================

  void clearCache() {
    _addressCache.clear();
    debugPrint('📍 LocationValidator: Address cache cleared');
  }

  int get cacheSize => _addressCache.length;

  // ===========================================================================
  // SAFE HELPERS
  // ===========================================================================

  Map<String, dynamic> _parseMapSafe(dynamic value) {
    try {
      if (value == null) return {};
      
      if (value is Map<String, dynamic>) {
        return value;
      }
      
      if (value is Map) {
        final result = <String, dynamic>{};
        value.forEach((key, val) {
          if (key is String) {
            result[key] = val;
          } else {
            result[key.toString()] = val;
          }
        });
        return result;
      }

      debugPrint('📍 LocationValidator: Unknown map type: ${value.runtimeType}');
      return {};
    } catch (e) {
      debugPrint('📍 LocationValidator: Parse map error: $e');
      return {};
    }
  }

  double? _parseDoubleSafe(dynamic value) {
    try {
      if (value == null) return null;

      if (value is double) {
        if (value.isNaN || value.isInfinite) return null;
        return value;
      }

      if (value is int) {
        return value.toDouble();
      }

      if (value is num) {
        final result = value.toDouble();
        if (result.isNaN || result.isInfinite) return null;
        return result;
      }

      if (value is String) {
        final cleaned = value.trim().replaceAll(',', '.');
        final result = double.tryParse(cleaned);
        if (result == null || result.isNaN || result.isInfinite) return null;
        return result;
      }

      final str = value.toString().trim();
      if (str.isEmpty || str == 'null') return null;
      
      final result = double.tryParse(str);
      if (result == null || result.isNaN || result.isInfinite) return null;
      return result;
    } catch (e) {
      debugPrint('📍 LocationValidator: Failed to parse double: $value ($e)');
      return null;
    }
  }

  bool _isValidCoordinate(double lat, double lng) {
    if (lat.isNaN || lng.isNaN) return false;
    if (lat.isInfinite || lng.isInfinite) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  /// 🔥🔥🔥 GET MAXIMUM RADIUS - DENGAN VALIDASI KETAT
  double _getMaximumRadiusSafe(dynamic lokasiData) {
    try {
      final lokasi = _parseMapSafe(lokasiData);
      
      // 🔥 1. Cek custom radius_meter (prioritas utama)
      final customMeter = _parseDoubleSafe(lokasi['radius_meter']);
      if (customMeter != null && customMeter > 0) {
        return _clampRadius(customMeter, 'radius_meter');
      }

      // 🔥 2. Cek custom radius_km (konversi ke meter)
      final customKm = _parseDoubleSafe(lokasi['radius_km']);
      if (customKm != null && customKm > 0) {
        return _clampRadius(customKm * 1000, 'radius_km');
      }

      // 🔥 3. Cek field radius generik
      final radius = _parseDoubleSafe(lokasi['radius']);
      if (radius != null && radius > 0) {
        return _clampRadius(radius, 'radius');
      }

      // 🔥 4. Cek field max_radius
      final maxRadius = _parseDoubleSafe(lokasi['max_radius']);
      if (maxRadius != null && maxRadius > 0) {
        return _clampRadius(maxRadius, 'max_radius');
      }

      // 🔥 5. Cek field radius_absensi (custom field)
      final radiusAbsensi = _parseDoubleSafe(lokasi['radius_absensi']);
      if (radiusAbsensi != null && radiusAbsensi > 0) {
        return _clampRadius(radiusAbsensi, 'radius_absensi');
      }

      // 🔥 6. Fallback berdasarkan tipe lokasi
      final jenis = _safeString(lokasi['tipe_lokasi'] ?? lokasi['jenis'] ?? '')
          .toLowerCase();

      if (jenis.contains('kantor') || 
          jenis.contains('office') || 
          jenis.contains('gedung') || 
          jenis.contains('building') ||
          jenis.contains('ruang')) {
        debugPrint('📍 LocationValidator: Using OFFICE radius: ${formatDistance(defaultRadiusOffice)}');
        return defaultRadiusOffice;
      }

      // 🔥 Default: project/lapangan (300 meter)
      debugPrint('📍 LocationValidator: Using PROJECT radius: ${formatDistance(defaultRadiusProject)}');
      return defaultRadiusProject;
    } catch (e) {
      debugPrint('📍 LocationValidator: Error getting max radius: $e');
      return defaultRadiusProject;
    }
  }

  /// 🔥 Clamp radius ke batas yang diizinkan
  double _clampRadius(double radius, String source) {
    if (radius > maximumAllowedRadius) {
      debugPrint('⚠️ LocationValidator: Radius $source terlalu besar (${formatDistance(radius)}), '
          'dibatasi ke maksimum ${formatDistance(maximumAllowedRadius)}');
      return maximumAllowedRadius;
    }
    
    if (radius < minimumAllowedRadius) {
      debugPrint('⚠️ LocationValidator: Radius $source terlalu kecil (${formatDistance(radius)}), '
          'menggunakan minimum ${formatDistance(minimumAllowedRadius)}');
      return minimumAllowedRadius;
    }
    
    debugPrint('📍 LocationValidator: Using custom radius from $source: ${formatDistance(radius)}');
    return radius;
  }

  double? _safeDistanceBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    try {
      if (!_isValidCoordinate(lat1, lng1) || !_isValidCoordinate(lat2, lng2)) {
        return null;
      }

      final distance = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

      if (distance.isNaN || distance.isInfinite || distance < 0) {
        return calculateDistanceManual(lat1, lng1, lat2, lng2);
      }

      return distance;
    } catch (e) {
      debugPrint('📍 LocationValidator: Geolocator distance failed: $e');
      return calculateDistanceManual(lat1, lng1, lat2, lng2);
    }
  }

  Map<String, dynamic> _successNoReference() {
    return {
      'valid': true,
      'distance': null,
      'distance_text': '-',
      'max_radius': null,
      'max_radius_text': '-',
      'message': 'Tidak ada koordinat referensi - lokasi diizinkan',
      'no_reference': true,
    };
  }

  Map<String, dynamic> _failure({
    required String message,
    required String errorCode,
    String? error,
  }) {
    return {
      'valid': false,
      'distance': null,
      'distance_text': '-',
      'max_radius': null,
      'max_radius_text': '-',
      'message': message,
      'error_code': errorCode,
      if (error != null) 'error': error,
    };
  }

  // ===========================================================================
  // DISTANCE CALCULATION - HAVERSINE
  // ===========================================================================

  double calculateDistanceManual(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000.0;

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    final distance = earthRadius * c;

    if (distance.isNaN || distance.isInfinite || distance < 0) {
      return double.maxFinite;
    }

    return distance;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // ===========================================================================
  // FORMATTER
  // ===========================================================================

  String formatDistance(double? meters) {
    if (meters == null || meters.isNaN || meters.isInfinite) {
      return '-';
    }

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} meter';
    }

    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
}