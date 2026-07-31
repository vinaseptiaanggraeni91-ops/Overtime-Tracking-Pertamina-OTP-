// lib/core/services/location_service.dart
// 🔥 FINAL VERSION - DILENGKAPI NETWORK MONITORING

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '/core/services/network_service.dart'; // 🔥 NETWORK SERVICE

/// Service untuk mengelola lokasi
/// Mendukung: GPS, Nominatim geocoding, riwayat lokasi, deteksi fake GPS
/// 🔥 Dilengkapi network monitoring
class LocationService {
  // ==================== KONSTANTA KANTOR ====================
  
  /// Koordinat Kantor PGE Kamojang
  static const double kantorLat = -7.134711;
  static const double kantorLng = 107.799540;
  
  /// Radius kantor dalam meter (300m)
  static const double radiusKantor = 300;
  
  /// Radius kantor dalam kilometer (untuk display)
  static const double radiusKm = 0.3; // 300m = 0.3km
  
  /// Alamat resmi kantor
  static const String alamatKantor = "PT Pertamina Geothermal Energy Area Kamojang";
  
  /// Nama kantor
  static const String namaKantor = "Kantor PGE Kamojang";

  // ==================== DEPENDENCIES ====================
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 🔥 NETWORK SERVICE
  static final NetworkService _networkService = NetworkService();

  // ==================== KONSTANTA API ====================
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'OvertimeApp-PGE/1.0';
  static const Duration _apiTimeout = Duration(seconds: 10);
  static const Duration _gpsTimeout = Duration(seconds: 15);

  // ==================== 🔥 NETWORK CHECK HELPERS ====================

  /// Cek koneksi sync
  static bool _checkConnection(String operationName) {
    if (!_networkService.isOnline) {
      debugPrint('⚠️ [$operationName] Dibatalkan - Tidak ada koneksi internet');
      return false;
    }
    return true;
  }

  /// Cek koneksi async
  static Future<bool> _checkConnectionAsync(String operationName) async {
    final isConnected = await _networkService.checkConnection();
    if (!isConnected) {
      debugPrint('⚠️ [$operationName] Dibatalkan - Tidak ada koneksi internet');
    }
    return isConnected;
  }

  // ==================== GET CURRENT POSITION ====================

  /// Mendapatkan posisi GPS saat ini
  /// [highAccuracy] - Jika true, gunakan akurasi terbaik (lebih lambat)
  /// [timeout] - Batas waktu mendapatkan posisi
  static Future<Position> getCurrentPosition({
    bool highAccuracy = true,
    Duration? timeout,
  }) async {
    try {
      // Cek permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak oleh pengguna');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkan.');
      }

      // Cek GPS enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('GPS/Lokasi tidak aktif. Nyalakan GPS terlebih dahulu.');
      }
      
      // Dapatkan posisi (GPS tidak butuh internet)
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: highAccuracy 
              ? LocationAccuracy.bestForNavigation 
              : LocationAccuracy.high,
          timeLimit: timeout ?? _gpsTimeout,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error getting current position: $e');
      rethrow;
    }
  }

  /// Cek apakah GPS/Location service enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Cek status permission lokasi
  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request permission lokasi
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  // ==================== DISTANCE CALCULATION ====================

  /// Hitung jarak antara dua titik koordinat (dalam meter)
  static double calculateDistance(
    double lat1, 
    double lng1, 
    double lat2, 
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Cek apakah suatu koordinat di luar radius kantor
  static bool isOutsideRadius(double lat, double lng) {
    final distance = calculateDistance(kantorLat, kantorLng, lat, lng);
    return distance > radiusKantor;
  }

  /// Dapatkan jarak dari kantor (dalam meter)
  static double getDistanceFromKantor(double lat, double lng) {
    return calculateDistance(kantorLat, kantorLng, lat, lng);
  }

  /// Dapatkan jarak dari kantor dalam kilometer
  static double getDistanceFromKantorKm(double lat, double lng) {
    final distanceMeter = calculateDistance(kantorLat, kantorLng, lat, lng);
    return distanceMeter / 1000.0;
  }

  /// Dapatkan jarak dari kantor dalam format string (km atau m)
  static String getDistanceFromKantorFormatted(double lat, double lng) {
    final distance = getDistanceFromKantor(lat, lng);
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }
    return '${distance.toStringAsFixed(0)} m';
  }

  /// Cek apakah koordinat dalam radius tertentu dari kantor
  static bool isWithinRadius(double lat, double lng, double radiusMeter) {
    return calculateDistance(kantorLat, kantorLng, lat, lng) <= radiusMeter;
  }

  // ==================== KANTOR LOCATION ====================

  /// Mendapatkan data lokasi kantor
  static Map<String, dynamic> getKantorLocation() {
    return {
      'name': namaKantor,
      'address': alamatKantor,
      'lat': kantorLat,
      'lng': kantorLng,
      'is_kantor': true,
      'radius_meter': radiusKantor,
      'radius_km': radiusKm,
    };
  }

  /// Cek apakah koordinat adalah lokasi kantor
  static bool isKantorLocation(double lat, double lng) {
    return !isOutsideRadius(lat, lng);
  }

  // ==================== GEOCODING ====================

  /// Reverse geocode (koordinat -> alamat)
  static Future<Map<String, dynamic>?> reverseGeocode(
    double lat, 
    double lng,
  ) async {
    try {
      // Cek dulu apakah ini lokasi kantor (tidak butuh API)
      if (isKantorLocation(lat, lng)) {
        return {
          'address': alamatKantor,
          'lat': lat,
          'lng': lng,
          'is_proyek': false,
          'is_kantor': true,
          'distance_from_kantor': getDistanceFromKantor(lat, lng),
          'name': namaKantor,
        };
      }

      // 🔥 Cek koneksi sebelum panggil API Nominatim
      if (!_checkConnection('reverseGeocode')) {
        // Return basic info tanpa alamat detail
        return {
          'address': 'Alamat tidak tersedia (offline)',
          'lat': lat,
          'lng': lng,
          'is_proyek': true,
          'is_kantor': false,
          'distance_from_kantor': getDistanceFromKantor(lat, lng),
          'distance_from_kantor_km': getDistanceFromKantorKm(lat, lng),
          'offline': true,
        };
      }

      final url = Uri.parse(
        '$_nominatimBaseUrl/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1'
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      ).timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          return {
            'address': data['display_name'],
            'lat': lat,
            'lng': lng,
            'is_proyek': !isKantorLocation(lat, lng),
            'is_kantor': false,
            'distance_from_kantor': getDistanceFromKantor(lat, lng),
            'distance_from_kantor_km': getDistanceFromKantorKm(lat, lng),
            'raw_data': data,
          };
        }
      } else {
        debugPrint('⚠️ Nominatim returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error reverse geocoding: $e');
      
      // 🔥 Return basic info saat error
      return {
        'address': 'Gagal mendapatkan alamat',
        'lat': lat,
        'lng': lng,
        'is_proyek': true,
        'is_kantor': false,
        'distance_from_kantor': getDistanceFromKantor(lat, lng),
        'distance_from_kantor_km': getDistanceFromKantorKm(lat, lng),
        'error': e.toString(),
      };
    }
    return null;
  }

  /// Forward geocode (alamat -> koordinat)
  static Future<List<Map<String, dynamic>>?> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // 1. Cek apakah mencari kantor (tidak butuh API)
      if (query.toLowerCase().contains('kantor') || 
          query.toLowerCase().contains('pge') ||
          query.toLowerCase().contains('kamojang')) {
        return [{
          'lat': kantorLat,
          'lng': kantorLng,
          'address': alamatKantor,
          'name': namaKantor,
          'type': 'office',
          'category': 'office',
          'distance_from_kantor': 0.0,
          'distance_from_kantor_km': 0.0,
          'is_kantor': true,
          'source': 'internal',
        }];
      }

      // 2. Cari dari riwayat/rekomendasi dulu (Firestore)
      if (_checkConnection('searchLocation_recommendations')) {
        try {
          final recommendations = await getRecommendedLocations();
          final matchedRecommendations = recommendations.where((loc) {
            final name = (loc['name'] ?? '').toString().toLowerCase();
            final address = (loc['address'] ?? '').toString().toLowerCase();
            final searchQuery = query.toLowerCase();
            return name.contains(searchQuery) || address.contains(searchQuery);
          }).toList();
          
          if (matchedRecommendations.isNotEmpty) {
            debugPrint('📍 Found ${matchedRecommendations.length} results from recommendations');
            return matchedRecommendations;
          }
        } catch (e) {
          debugPrint('⚠️ Gagal cari dari rekomendasi: $e');
        }
      }

      // 3. Cari dari Nominatim API (butuh internet)
      if (!_checkConnection('searchLocation_nominatim')) {
        debugPrint('⚠️ Offline - hanya menampilkan hasil lokal');
        return [];
      }

      debugPrint('🔍 Searching Nominatim for: $query');
      final url = Uri.parse(
        '$_nominatimBaseUrl/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=10'
        '&addressdetails=1'
        '&countrycodes=id' // Batasi ke Indonesia
      );

      final response = await http.get(
        url, 
        headers: {'User-Agent': _userAgent},
      ).timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return data.map((item) {
            final lat = double.parse(item['lat']?.toString() ?? '0');
            final lng = double.parse(item['lon']?.toString() ?? '0');
            final distance = getDistanceFromKantor(lat, lng);
            return {
              'lat': lat,
              'lng': lng,
              'address': item['display_name'] ?? 'Alamat tidak diketahui',
              'name': _getDisplayName(item['display_name'] ?? ''),
              'type': item['type'] ?? '',
              'category': item['category'] ?? '',
              'distance_from_kantor': distance,
              'distance_from_kantor_km': distance / 1000.0,
              'is_outside_radius': distance > radiusKantor,
              'is_kantor': false,
              'source': 'nominatim',
            };
          }).toList();
        }
      }
      
      debugPrint('⚠️ No results found for: $query');
      return [];
      
    } catch (e) {
      debugPrint('❌ Error searching location: $e');
      return null;
    }
  }

  // ==================== LOCATION HISTORY ====================

  /// Mendapatkan rekomendasi lokasi berdasarkan riwayat
  static Future<List<Map<String, dynamic>>> getRecommendedLocations() async {
    try {
      // 🔥 Cek koneksi
      if (!_checkConnection('getRecommendedLocations')) return [];
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ No current user for recommendations');
        return [];
      }

      // Ambil dari lembur_mitra
      final snapshot = await _firestore
          .collection('lembur_mitra')
          .where('pengawas_id', isEqualTo: currentUser.uid)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();

      final Map<String, Map<String, dynamic>> locationFrequency = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lokasi = data['lokasi'] as Map<String, dynamic>?;
        
        if (lokasi != null && 
            lokasi['latitude'] != null && 
            lokasi['longitude'] != null) {
          final lat = (lokasi['latitude'] as num).toDouble();
          final lng = (lokasi['longitude'] as num).toDouble();
          final alamat = (lokasi['alamat'] ?? 'Lokasi Lembur').toString();
          final distance = getDistanceFromKantor(lat, lng);
          
          // Buat key unik dari koordinat (4 desimal ~ 11m akurasi)
          final key = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
          
          if (locationFrequency.containsKey(key)) {
            locationFrequency[key]!['count'] = 
                (locationFrequency[key]!['count'] as int) + 1;
            locationFrequency[key]!['last_used'] = 
                (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
          } else {
            locationFrequency[key] = {
              'name': _getLocationName(alamat, lokasi),
              'address': alamat,
              'lat': lat,
              'lng': lng,
              'count': 1,
              'last_used': (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'distance_from_kantor': distance,
              'distance_from_kantor_km': distance / 1000.0,
              'is_outside_radius': distance > radiusKantor,
              'is_kantor': distance <= radiusKantor,
              'source': 'history',
            };
          }
        }
      }

      // Sorting: count DESC, last_used DESC
      List<Map<String, dynamic>> recommendations = locationFrequency.values.toList();
      recommendations.sort((a, b) {
        final countCompare = (b['count'] as int).compareTo(a['count'] as int);
        if (countCompare != 0) return countCompare;
        return (b['last_used'] as DateTime).compareTo(a['last_used'] as DateTime);
      });

      // Ambil top 10
      recommendations = recommendations.take(10).toList();

      debugPrint('📍 Got ${recommendations.length} recommended locations');
      return recommendations;
      
    } catch (e) {
      debugPrint('❌ Error getting recommended locations: $e');
      return [];
    }
  }

  /// Mendapatkan riwayat lokasi terbaru
  static Future<List<Map<String, dynamic>>> getRecentLocations({
    int limit = 20,
  }) async {
    try {
      // 🔥 Cek koneksi
      if (!_checkConnection('getRecentLocations')) return [];
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('lembur_mitra')
          .where('pengawas_id', isEqualTo: currentUser.uid)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> locations = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lokasi = data['lokasi'] as Map<String, dynamic>?;
        
        if (lokasi != null && 
            lokasi['latitude'] != null && 
            lokasi['longitude'] != null) {
          final lat = (lokasi['latitude'] as num).toDouble();
          final lng = (lokasi['longitude'] as num).toDouble();
          final alamat = (lokasi['alamat'] ?? 'Lokasi Lembur').toString();
          final distance = getDistanceFromKantor(lat, lng);
          
          locations.add({
            'name': _getLocationName(alamat, lokasi),
            'address': alamat,
            'lat': lat,
            'lng': lng,
            'rt': lokasi['rt'] ?? '',
            'rw': lokasi['rw'] ?? '',
            'timestamp': (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'tanggal': _formatTanggalFull(
                (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now()),
            'distance_from_kantor': distance,
            'distance_from_kantor_km': distance / 1000.0,
            'is_outside_radius': distance > radiusKantor,
            'is_kantor': distance <= radiusKantor,
            'tipe_lokasi': lokasi['tipe_lokasi'] ?? 'proyek',
            'source': 'history',
          });
        }
      }

      return locations;
      
    } catch (e) {
      debugPrint('❌ Error getting recent locations: $e');
      return [];
    }
  }

  /// Simpan lokasi ke riwayat
  static Future<void> saveLocationToHistory({
    required double lat,
    required double lng,
    required String address,
    String? rt,
    String? rw,
  }) async {
    try {
      // 🔥 Cek koneksi
      if (!_checkConnection('saveLocationToHistory')) {
        debugPrint('⚠️ Offline - lokasi tidak disimpan ke Firestore');
        return;
      }
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final distance = getDistanceFromKantor(lat, lng);

      final historyRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('location_history')
          .doc();

      await historyRef.set({
        'latitude': lat,
        'longitude': lng,
        'address': address,
        'rt': rt ?? '',
        'rw': rw ?? '',
        'used_at': FieldValue.serverTimestamp(),
        'count': 1,
        'is_outside_radius': distance > radiusKantor,
        'is_kantor': distance <= radiusKantor,
        'distance_from_kantor': distance,
        'distance_from_kantor_km': distance / 1000.0,
      });
      
      debugPrint('✅ Lokasi disimpan ke riwayat: $address');
      
    } catch (e) {
      debugPrint('❌ Error saving location history: $e');
    }
  }

  // ==================== FAKE GPS DETECTION ====================

  /// Deteksi fake GPS / mock location
  static Future<Map<String, dynamic>> detectFakeGPS() async {
    try {
      // GPS check tidak butuh internet
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, 
          timeLimit: Duration(seconds: 15),
        ),
      );
      
      final isMocked = position.isMocked;
      final isLowAccuracy = position.accuracy > 100;
      final isSuspicious = isMocked || isLowAccuracy;
      
      String? reason;
      if (isMocked) reason = 'Mock location terdeteksi';
      if (isLowAccuracy) reason = 'Akurasi GPS rendah (${position.accuracy.toStringAsFixed(0)}m)';
      
      final distance = calculateDistance(
        kantorLat, kantorLng,
        position.latitude, position.longitude,
      );
      
      debugPrint('🛰️ GPS Check - Mocked: $isMocked, Accuracy: ${position.accuracy}m, Distance: ${distance.toStringAsFixed(0)}m');
      
      return {
        'is_fake': isSuspicious,
        'is_mocked': isMocked,
        'is_low_accuracy': isLowAccuracy,
        'accuracy': position.accuracy,
        'reason': reason,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'distance_from_kantor': distance,
        'distance_from_kantor_km': distance / 1000.0,
        'is_outside_radius': distance > radiusKantor,
        'is_kantor': distance <= radiusKantor,
      };
    } catch (e) {
      debugPrint('❌ Error detecting fake GPS: $e');
      return {
        'is_fake': false,
        'is_mocked': false,
        'is_low_accuracy': false,
        'error': e.toString(),
      };
    }
  }

  /// Cek apakah posisi valid (tidak fake + dalam radius tertentu)
  static Future<bool> isPositionValid({
    double? maxRadiusFromKantor,
    bool checkFakeGPS = true,
  }) async {
    try {
      if (checkFakeGPS) {
        final fakeCheck = await detectFakeGPS();
        if (fakeCheck['is_fake'] == true) {
          debugPrint('⚠️ Posisi tidak valid: ${fakeCheck['reason']}');
          return false;
        }
      }
      
      if (maxRadiusFromKantor != null) {
        final position = await getCurrentPosition();
        final distance = calculateDistance(
          kantorLat, kantorLng,
          position.latitude, position.longitude,
        );
        if (distance > maxRadiusFromKantor) {
          debugPrint('⚠️ Di luar radius maksimal: ${distance.toStringAsFixed(0)}m');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error validating position: $e');
      return false;
    }
  }

  /// Dapatkan informasi lengkap tentang suatu lokasi
  static Map<String, dynamic> getLocationInfo(double lat, double lng) {
    final distance = getDistanceFromKantor(lat, lng);
    final isOutside = distance > radiusKantor;
    
    return {
      'latitude': lat,
      'longitude': lng,
      'distance_from_kantor_meter': distance,
      'distance_from_kantor_km': distance / 1000.0,
      'distance_formatted': formatDistance(distance),
      'is_outside_radius': isOutside,
      'is_kantor': !isOutside,
      'coordinate_formatted': formatCoordinate(lat, lng),
      'google_maps_url': getGoogleMapsUrl(lat, lng),
      'direction_url': getDirectionFromKantorUrl(lat, lng),
    };
  }

  // ==================== FORMATTING HELPERS ====================

  /// Format jarak untuk display
  static String formatDistance(double distanceMeter) {
    if (distanceMeter >= 1000) {
      return '${(distanceMeter / 1000).toStringAsFixed(2)} km';
    } else if (distanceMeter >= 1) {
      return '${distanceMeter.toStringAsFixed(0)} m';
    } else {
      return '< 1 m';
    }
  }

  /// Format koordinat untuk display
  static String formatCoordinate(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(6)}°$latDir, ${lng.abs().toStringAsFixed(6)}°$lngDir';
  }

  /// Dapatkan Google Maps URL
  static String getGoogleMapsUrl(double lat, double lng) {
    return 'https://www.google.com/maps?q=$lat,$lng';
  }

  /// Dapatkan Google Maps direction URL dari kantor
  static String getDirectionFromKantorUrl(double lat, double lng) {
    return 'https://www.google.com/maps/dir/$kantorLat,$kantorLng/$lat,$lng';
  }

  /// Format tanggal (public)
  static String formatTanggal(DateTime date, {bool full = false}) {
    if (full) {
      return _formatTanggalFull(date);
    }
    return _formatTanggalShort(date);
  }

  // ==================== PRIVATE HELPERS ====================

  /// Ekstrak nama dari display name Nominatim
  static String _getDisplayName(String fullAddress) {
    final parts = fullAddress.split(',');
    if (parts.length >= 3) {
      return parts.sublist(0, 3).join(',').trim();
    }
    return fullAddress.length > 50 
        ? '${fullAddress.substring(0, 50)}...' 
        : fullAddress;
  }

  /// Format nama lokasi dengan RT/RW
  static String _getLocationName(String address, [Map<String, dynamic>? lokasi]) {
    String base = '';
    final parts = address.split(',');
    if (parts.isNotEmpty) {
      base = parts[0].trim();
    } else {
      base = address.length > 30 ? '${address.substring(0, 30)}...' : address;
    }

    if (lokasi != null) {
      final rt = lokasi['rt']?.toString();
      final rw = lokasi['rw']?.toString();
      if (rt != null && rt.isNotEmpty) base += ' RT $rt';
      if (rw != null && rw.isNotEmpty) base += ' RW $rw';
    }
    return base;
  }

  /// Format tanggal singkat
  static String _formatTanggalShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Format tanggal lengkap
  static String _formatTanggalFull(DateTime date) {
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }
}