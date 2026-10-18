// lib/dashboard/manager/location_menu_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/core/services/live_location_service.dart';
import '/core/services/live_location_manager.dart';
import '/widgets/bottom_nav/app_bottom_nav.dart';

class LocationMenuScreen extends StatefulWidget {
  final String userRole;
  final String? timId;
  final String? fungsiId;
  final int currentIndex;

  const LocationMenuScreen({
    super.key,
    required this.userRole,
    this.timId,
    this.fungsiId,
    this.currentIndex = 2,
  });

  @override
  State<LocationMenuScreen> createState() => _LocationMenuScreenState();
}

class _LocationMenuScreenState extends State<LocationMenuScreen>
    with TickerProviderStateMixin {

  final LiveLocationService _locationService = LiveLocationService();
  final LiveLocationManager _locationManager = LiveLocationManager();

  late TabController _tabController;
  late MapController _mapController;
  Map<String, dynamic>? selectedLocation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'Semua';
  String _sortBy = 'recent';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;

  Map<String, LiveLocationData> _liveLocations = {};
  Map<String, List<LatLng>> _locationPaths = {};
  Timer? _refreshTimer;
  Timer? _movementTimer;
  bool _isLoading = true;
  bool _isRefreshing = false;

  // 🔥 DETEKSI PERGERAKAN — kombinasi raw GPS speed + displacement aktual,
  // supaya gak salah deteksi "bergerak" cuma gara-gara GPS jitter/drift.
  final Map<String, LatLng> _lastMovementPoint = {};
  final Map<String, DateTime> _lastMovementTimestamp = {};
  final Map<String, bool> _movementCache = {};
  final Map<String, double> _speedKmhCache = {};
  static const Distance _distanceCalc = Distance();
  // Pergeseran minimal (meter) biar gak keanggep gerak gara-gara noise GPS
  static const double _minMovementMeters = 8.0;
  // Kecepatan minimal (km/jam) buat dianggap "jalan" — di bawah ini dianggap diam
  static const double _minWalkingSpeedKmh = 1.5;
  // Kecepatan wajar maksimal (km/jam) — di atas ini raw GPS speed dicurigai glitch
  static const double _maxSaneSpeedKmh = 25.0;

  VoidCallback _locationListener = () {};

  bool _canViewAll = false;
  bool _canViewTim = false;
  bool _canViewOwnOnly = false;
  String _accessMessage = '';

  // 🔥 Toggle Satelit/Jalan
  bool _isSatellite = true;

  // 🔥🔥🔥 GOOGLE MAPS TILE URLS
  static const String _satelliteUrl =
      'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
  static const String _streetUrl =
      'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  static const String _fallbackUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  String get _currentTileUrl => _isSatellite ? _satelliteUrl : _streetUrl;

  // 🔥 Tambahan: User data untuk bottom nav
  String? _userId;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _mapController = MapController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _setupAccessControl();
    _loadUserData();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupRealtimeListener();
        _startMovementDetection();
      }
    });
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _userName = user.displayName ?? user.email?.split('@').first ?? 'User';
    }
  }

  void _setupAccessControl() {
    switch (widget.userRole) {
      case 'superadmin':
      case 'manager':
      case 'manager_hsse':
        _canViewAll = true;
        _canViewTim = true;
        _canViewOwnOnly = false;
        _accessMessage = 'Anda dapat melihat semua lokasi mitra';
        break;
      case 'pengawas':
        _canViewAll = false;
        _canViewTim = true;
        _canViewOwnOnly = false;
        _accessMessage = 'Anda dapat melihat lokasi tim Anda';
        break;
      case 'mitra':
        _canViewAll = false;
        _canViewTim = false;
        _canViewOwnOnly = true;
        _accessMessage = 'Anda hanya dapat melihat lokasi Anda sendiri';
        break;
      default:
        _canViewAll = false;
        _canViewTim = false;
        _canViewOwnOnly = true;
        _accessMessage = 'Akses terbatas';
    }
  }

  void _setupRealtimeListener() {
    _locationService.removeListener(_locationListener);
    _locationService.stopListening();
    
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_canViewAll) {
      _locationService.listenToAllActiveLocations();
    } else if (_canViewTim) {
      _locationService.listenToAllActiveLocations();
    } else if (currentUser != null && _canViewOwnOnly) {
      _locationService.listenToOwnLocation(currentUser.uid);
    } else {
      _isLoading = false;
    }

    _locationListener = () {
      if (!mounted) return;
      _processLocationUpdate();
    };

    _locationService.addListener(_locationListener);

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _processLocationUpdate();
    });
  }

  void _processLocationUpdate() {
    final newLocations = _locationService.latestLocations;
    
    for (final entry in newLocations.entries) {
      final userId = entry.key;
      final location = entry.value;

      if (!_locationPaths.containsKey(userId)) {
        _locationPaths[userId] = [];
      }

      final lastPoint = _locationPaths[userId]!.isNotEmpty
          ? _locationPaths[userId]!.last
          : null;
      final newPoint = LatLng(location.latitude, location.longitude);

      if (lastPoint == null ||
          (lastPoint.latitude != newPoint.latitude ||
              lastPoint.longitude != newPoint.longitude)) {
        _locationPaths[userId]!.add(newPoint);

        if (_locationPaths[userId]!.length > 100) {
          _locationPaths[userId]!.removeAt(0);
        }
      }

      _updateMovementInfo(userId, location);
    }

    // Bersihkan cache buat user yang udah gak ada di daftar aktif
    _movementCache.removeWhere((id, _) => !newLocations.containsKey(id));
    _speedKmhCache.removeWhere((id, _) => !newLocations.containsKey(id));
    _lastMovementPoint.removeWhere((id, _) => !newLocations.containsKey(id));
    _lastMovementTimestamp.removeWhere((id, _) => !newLocations.containsKey(id));

    setState(() {
      _liveLocations = Map.from(newLocations);
      _isLoading = false;
    });
  }

  // 🔥 DETEKSI PERGERAKAN AKURAT
  //
  // Raw GPS speed (`loc.speed`) sendirian gak cukup diandalkan — GPS bisa
  // "ngelantur" pas sinyal lemah dan nunjukin speed > 0 meski orangnya diam.
  // Jadi di sini kita hitung juga displacement aktual antar 2 titik terakhir,
  // dan cuma dianggap "beneran bergerak" kalau pergeserannya jelas melebihi
  // margin akurasi GPS itu sendiri.
  void _updateMovementInfo(String userId, LiveLocationData loc) {
    final now = loc.timestamp;
    final point = LatLng(loc.latitude, loc.longitude);

    final lastPoint = _lastMovementPoint[userId];
    final lastTime = _lastMovementTimestamp[userId];

    double computedSpeedKmh = 0;
    bool computedMoving = false;

    if (lastPoint != null && lastTime != null) {
      final distanceMeters = _distanceCalc.distance(lastPoint, point);
      final secondsElapsed = now.difference(lastTime).inSeconds;

      // Margin toleransi = akurasi GPS saat ini (dibatasi wajar 5-30m)
      final accuracyMargin = (loc.accuracy ?? 10).clamp(5, 30);
      final movementThreshold = max(_minMovementMeters, accuracyMargin);

      if (secondsElapsed > 0 && secondsElapsed < 120 && distanceMeters > movementThreshold) {
        final speedMs = distanceMeters / secondsElapsed;
        computedSpeedKmh = speedMs * 3.6;
        computedMoving = computedSpeedKmh >= _minWalkingSpeedKmh;
      }
    }

    // Raw speed dari sensor GPS device (kalau ada)
    final rawSpeedKmh = (loc.speed ?? 0) * 3.6;
    final rawMoving = rawSpeedKmh >= _minWalkingSpeedKmh && rawSpeedKmh < _maxSaneSpeedKmh;

    // Dianggap bergerak kalau salah satu sinyal (displacement ATAU raw speed) kuat mendukung
    final isMoving = computedMoving || rawMoving;
    final displaySpeedKmh = computedSpeedKmh > 0 ? computedSpeedKmh : rawSpeedKmh;

    _movementCache[userId] = isMoving;
    _speedKmhCache[userId] = displaySpeedKmh.clamp(0, _maxSaneSpeedKmh);

    _lastMovementPoint[userId] = point;
    _lastMovementTimestamp[userId] = now;
  }

  void _startMovementDetection() {
    _movementTimer?.cancel();
    _movementTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _movementTimer?.cancel();
    _locationService.removeListener(_locationListener);
    _locationService.stopListening();
    _tabController.dispose();
    _mapController.dispose();
    _animationController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    _setupRealtimeListener();
    if (_locationManager.isActive) {
      await _locationManager.sendLocationNow();
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _liveLocations = Map.from(_locationService.latestLocations);
        _isRefreshing = false;
      });
    }
  }

  // ==========================================================================
  // DATA PROCESSING
  // ==========================================================================

  List<Map<String, dynamic>> get _filteredLocations {
    var filtered = _liveLocations.entries.map((entry) {
      final loc = entry.value;
      final status = _determineStatus(loc);
      return {
        'id': entry.key,
        'name': loc.userName ?? 'Unknown',
        'address': loc.address ?? '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
        'lat': loc.latitude,
        'lng': loc.longitude,
        'status': status,
        'workers': 1,
        'battery': loc.batteryLevel != null ? '${loc.batteryLevel!.toStringAsFixed(0)}%' : '--',
        'signal': '--',
        'accuracy': loc.accuracy != null ? '${loc.accuracy!.toStringAsFixed(1)}m' : '--',
        'lastUpdate': loc.timestamp,
        'warning': _getWarningMessage(loc),
        'heading': loc.heading ?? 0,
        'speed': loc.speed ?? 0,
        'isMoving': _movementCache[entry.key] ?? false,
        'speedKmh': _speedKmhCache[entry.key] ?? 0.0,
        'altitude': loc.altitude ?? 0,
        'isActive': loc.isActive,
        'userRole': loc.userRole ?? 'mitra',
        'fungsi': loc.userFungsi ?? '',
        'lemburId': loc.lemburId ?? '',
      };
    }).toList();

    if (_statusFilter != 'Semua') {
      filtered = filtered.where((l) => l['status'] == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((l) {
        final name = (l['name'] as String).toLowerCase();
        final address = (l['address'] as String).toLowerCase();
        return name.contains(query) || address.contains(query);
      }).toList();
    }
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        break;
      case 'recent':
        filtered.sort((a, b) => (b['lastUpdate'] as DateTime).compareTo(a['lastUpdate'] as DateTime));
        break;
      case 'status':
        final order = {'Darurat': 0, 'Warning': 1, 'Normal': 2};
        filtered.sort((a, b) => (order[a['status']] ?? 99).compareTo(order[b['status']] ?? 99));
        break;
    }
    return filtered;
  }

  String _determineStatus(LiveLocationData loc) {
    if (!loc.isActive) return 'Warning';
    final diff = DateTime.now().difference(loc.timestamp);
    if (diff.inMinutes > 30) return 'Darurat';
    if (diff.inMinutes > 10) return 'Warning';
    final battery = loc.batteryLevel ?? 100;
    if (battery < 15) return 'Darurat';
    if (battery < 30) return 'Warning';
    return 'Normal';
  }

  String? _getWarningMessage(LiveLocationData loc) {
    final diff = DateTime.now().difference(loc.timestamp);
    if (diff.inMinutes > 30) return 'Tidak ada update > 30 menit';
    if (diff.inMinutes > 10) return 'Update terakhir > 10 menit';
    final battery = loc.batteryLevel ?? 100;
    if (battery < 15) return 'Battery kritis (${battery.toStringAsFixed(0)}%)';
    if (battery < 30) return 'Battery rendah (${battery.toStringAsFixed(0)}%)';
    if (!loc.isActive) return 'Tracking tidak aktif';
    return null;
  }

  Map<String, int> get _stats {
    final locs = _filteredLocations;
    return {
      'total': locs.length,
      'normal': locs.where((l) => l['status'] == 'Normal').length,
      'warning': locs.where((l) => l['status'] == 'Warning').length,
      'darurat': locs.where((l) => l['status'] == 'Darurat').length,
    };
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '--';
    DateTime time;
    if (timestamp is DateTime) {
      time = timestamp;
    } else if (timestamp is int) {
      time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return '--';
    }
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 30) return '${(difference.inDays / 30).floor()} bln';
    if (difference.inDays > 0) return '${difference.inDays} hr';
    if (difference.inHours > 0) return '${difference.inHours} jam';
    if (difference.inMinutes > 0) return '${difference.inMinutes} mnt';
    return 'baru saja';
  }

  Future<void> _launchMaps(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
        );
      }
    }
  }

  // 🔥🔥🔥 MAP DIALOG
  void _showLokasiOnMap(double lat, double lng, String alamat) {
    showDialog(
      context: context,
      builder: (ctx) => _MapViewDialog(
        lat: lat,
        lng: lng,
        alamat: alamat,
      ),
    );
  }

  // ==========================================================================
  // ACCESS BANNER
  // ==========================================================================

  Widget _buildAccessBanner() {
    IconData icon;
    Color color;
    if (_canViewAll) {
      icon = Icons.admin_panel_settings_rounded;
      color = Colors.green;
    } else if (_canViewTim) {
      icon = Icons.groups_rounded;
      color = Colors.blue;
    } else {
      icon = Icons.person_rounded;
      color = Colors.orange;
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 10), Expanded(child: Text(_accessMessage, style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w500)))]),
    );
  }

  // ==========================================================================
  // 🔥🔥🔥 LOCATION DETAIL — TANPA DURASI, STATUS PERANGKAT, HEADING
  // ==========================================================================

  void _showLocationDetail(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Container(
                margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: LinearGradient(colors: _getStatusGradient(location['status']), begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _getStatusColor(location['status']).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))]),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)), child: Icon(location['status'] == 'Darurat' ? Icons.dangerous_rounded : location['status'] == 'Warning' ? Icons.warning_rounded : Icons.location_on_rounded, color: Colors.white, size: 28)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(location['name'], style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 4), Text(location['address'], style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis)])),
                  _buildStatusChip(location['status'], large: true),
                ]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  // ✅ INFORMASI LOKASI
                  _buildSectionTitle('Informasi Lokasi'), const SizedBox(height: 8),
                  _buildDetailCard([
                    _buildDetailItem(Icons.explore_rounded, 'Koordinat', '${(location['lat'] as double).toStringAsFixed(4)}, ${(location['lng'] as double).toStringAsFixed(4)}'),
                    _buildDetailItem(Icons.access_time_rounded, 'Update Terakhir', _getTimeAgo(location['lastUpdate'])),
                    _buildDetailItem(Icons.precision_manufacturing_rounded, 'Akurasi', location['accuracy'] ?? '--'),
                  ]),
                  
                  // ❌ DURASI TRACKING DIHAPUS
                  
                  // ❌ STATUS PERANGKAT DIHAPUS
                  
                  // ✅ INFO TRACKING — TANPA HEADING
                  const SizedBox(height: 16),
                  _buildSectionTitle('Info Tracking'), const SizedBox(height: 8),
                  _buildDetailCard([
                    // ❌ HEADING DIHAPUS
                    _buildDetailItem(
                      (location['isMoving'] as bool? ?? false) ? Icons.directions_walk_rounded : Icons.accessibility_new_rounded,
                      'Status Gerak',
                      (location['isMoving'] as bool? ?? false)
                          ? '🚶 Sedang Jalan (${(location['speedKmh'] as double? ?? 0).toStringAsFixed(1)} km/j)'
                          : '🧍 Diam',
                    ),
                    _buildDetailItem(Icons.height_rounded, 'Altitude', '${(location['altitude'] as double).toStringAsFixed(1)}m'),
                    _buildDetailItem(Icons.badge_rounded, 'Role', location['userRole'] ?? 'mitra'),
                    if (location['lemburId'] != null && location['lemburId'] is String && (location['lemburId'] as String).isNotEmpty) 
                      _buildDetailItem(Icons.work_rounded, 'Lembur ID', (location['lemburId'] as String).length > 20 ? '${(location['lemburId'] as String).substring(0, 20)}...' : location['lemburId'] as String),
                  ]),
                  
                  // ✅ WARNING
                  if (location['warning'] != null) ...[
                    const SizedBox(height: 12), 
                    _buildAlertBox(icon: Icons.warning_amber_rounded, message: location['warning'], color: location['status'] == 'Darurat' ? Colors.red : Colors.orange),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // ✅ OPSI LOKASI — LIHAT DI PETA / GOOGLE MAPS
                  _buildSectionTitle('Lihat Lokasi'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLokasiOptionButton(
                          icon: Icons.satellite_rounded,
                          label: 'Lihat di Peta',
                          subtitle: 'Tampilan satelit',
                          color: const Color(0xFF6366F1),
                          onTap: () {
                            Navigator.pop(context);
                            _showLokasiOnMap(
                              location['lat'] as double,
                              location['lng'] as double,
                              location['address'] ?? 'Lokasi ${location['name']}',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), label: const Text('Tutup'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
                  ]),
                  const SizedBox(height: 20),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔥 TOMBOL OPSI LOKASI
  Widget _buildLokasiOptionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // UI COMPONENTS
  // ==========================================================================

  List<Color> _getStatusGradient(String status) {
    switch (status) {
      case 'Darurat': return [const Color(0xFFD32F2F), const Color(0xFFF44336)];
      case 'Warning': return [const Color(0xFFF57C00), const Color(0xFFFF9800)];
      case 'Normal': return [const Color(0xFF0D47A1), const Color(0xFF1976D2)];
      default: return [const Color(0xFF1976D2), const Color(0xFF42A5F5)];
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Darurat': return const Color(0xFFF44336);
      case 'Warning': return const Color(0xFFFF9800);
      case 'Normal': return const Color(0xFF4CAF50);
      default: return const Color(0xFF1976D2);
    }
  }

  Widget _buildSectionTitle(String title) => Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)));
  
  Widget _buildDetailCard(List<Widget> children) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))]), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: children)));
  
  Widget _buildDetailItem(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF1976D2).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: const Color(0xFF1976D2), size: 18)), const SizedBox(width: 12), Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600))), const SizedBox(width: 8), Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)), textAlign: TextAlign.right)))]));

  // 🔥 BADGE STATUS PERGERAKAN — dipakai di list card & marker
  Widget _buildMovementChip(bool isMoving) {
    final color = isMoving ? const Color(0xFF10B981) : Colors.grey.shade500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMoving ? Icons.directions_walk_rounded : Icons.accessibility_new_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            isMoving ? 'Jalan' : 'Diam',
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAlertBox({required IconData icon, required String message, required Color color}) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 12), Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 13, color: color, fontWeight: FontWeight.w500)))]));
  
  Widget _buildStatusChip(String status, {bool large = false}) {
    final color = _getStatusColor(status);
    final icon = status == 'Darurat' ? Icons.dangerous_rounded : status == 'Warning' ? Icons.warning_rounded : Icons.check_circle_rounded;
    return Container(padding: EdgeInsets.symmetric(horizontal: large ? 16 : 10, vertical: large ? 8 : 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(large ? 20 : 12), border: Border.all(color: color.withValues(alpha: 0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: large ? 16 : 12), const SizedBox(width: 4), Text(status, style: GoogleFonts.poppins(fontSize: large ? 13 : 10, color: color, fontWeight: FontWeight.w600))]));
  }

  Widget _buildPulsingDot({Color color = const Color(0xFF00E676)}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) => Container(
        width: 10 * _pulseController.value,
        height: 10 * _pulseController.value,
        decoration: BoxDecoration(color: color.withValues(alpha: _pulseController.value), shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildLiveIndicator() => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF4CAF50).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [_buildPulsingDot(), const SizedBox(width: 6), Text('LIVE', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))]));

  Widget _buildMitraEmptyState() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: Icon(Icons.person_pin_circle_rounded, size: 64, color: Colors.blue.shade300)), const SizedBox(height: 20), Text('Lokasi Anda', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))), const SizedBox(height: 8), Text('Mulai live tracking dari halaman absensi\nuntuk melihat lokasi Anda di sini.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600, height: 1.5)), const SizedBox(height: 24), Icon(Icons.arrow_upward_rounded, size: 32, color: Colors.blue.shade300), Text('Aktifkan dari Absensi Lembur', style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade400, fontWeight: FontWeight.w500))])));

  Widget _buildMiniInfo(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: Colors.grey.shade400), const SizedBox(width: 3), Text(text, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500))]);

  // ==========================================================================
  // FILTER & SEARCH
  // ==========================================================================

  Widget _buildFilterChips() {
    final filters = ['Semua', 'Normal', 'Warning', 'Darurat'];
    final colors = {'Semua': const Color(0xFF1976D2), 'Normal': const Color(0xFF4CAF50), 'Warning': const Color(0xFFFF9800), 'Darurat': const Color(0xFFF44336)};
    return SizedBox(height: 40, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: filters.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, index) {
      final filter = filters[index]; final isSelected = _statusFilter == filter; final color = colors[filter]!;
      return GestureDetector(onTap: () => setState(() => _statusFilter = filter), child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(gradient: isSelected ? LinearGradient(colors: [color, color.withValues(alpha: 0.8)]) : LinearGradient(colors: [Colors.white, Colors.grey.shade50]), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 1.5), boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : []), child: Text(filter == 'Semua' ? 'Semua (${_stats['total']})' : '$filter (${_stats[filter.toLowerCase()]})', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey.shade700))));
    }));
  }

  Widget _buildSearchBar() {
    return Container(margin: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: TextField(controller: _searchController, onChanged: (value) => setState(() => _searchQuery = value), style: GoogleFonts.poppins(fontSize: 14), decoration: InputDecoration(hintText: 'Cari lokasi...', hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13), prefixIcon: Container(margin: const EdgeInsets.all(8), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF1565C0)]), borderRadius: BorderRadius.all(Radius.circular(10))), child: const Icon(Icons.search_rounded, color: Colors.white, size: 20)), suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : _buildSortButton(), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5)))));
  }

  Widget _buildSortButton() => PopupMenuButton<String>(icon: Icon(Icons.sort_rounded, color: Colors.grey.shade600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), onSelected: (value) => setState(() => _sortBy = value), itemBuilder: (context) => [PopupMenuItem(value: 'recent', child: Row(children: [Icon(Icons.access_time_rounded, color: _sortBy == 'recent' ? const Color(0xFF1976D2) : Colors.grey), const SizedBox(width: 10), const Text('Terbaru')])), PopupMenuItem(value: 'status', child: Row(children: [Icon(Icons.warning_rounded, color: _sortBy == 'status' ? const Color(0xFF1976D2) : Colors.grey), const SizedBox(width: 10), const Text('Prioritas')])), PopupMenuItem(value: 'name', child: Row(children: [Icon(Icons.sort_by_alpha_rounded, color: _sortBy == 'name' ? const Color(0xFF1976D2) : Colors.grey), const SizedBox(width: 10), const Text('Nama (A-Z)')]))]);

  int _getNavIndex() {
    return widget.currentIndex;
  }

  // ==========================================================================
  // MAIN BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final hasNoData = _liveLocations.isEmpty && !_isLoading;
    final isMitra = widget.userRole == 'mitra';
    
    final subtitleText = _canViewAll 
        ? '${_liveLocations.length} lokasi aktif' 
        : _canViewTim 
            ? 'Tim Anda' 
            : 'Lokasi Anda';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pemantauan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!_isLoading)
                    Text(
                      subtitleText,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          if (!_isLoading && !hasNoData) 
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildLiveIndicator(),
            ),
          IconButton(
            icon: Icon(
              _isRefreshing ? Icons.sync_rounded : Icons.refresh_rounded,
              size: 20,
              color: Colors.white,
            ),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Peta'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Daftar'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1976D2)),
                  SizedBox(height: 16),
                  Text('Memuat data lokasi...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF1976D2),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildAccessBanner(),
                    if (isMitra && hasNoData)
                      Expanded(child: _buildMitraEmptyState())
                    else ...[
                      _buildStatsOverview(),
                      _buildFilterChips(),
                      const SizedBox(height: 8),
                      _buildSearchBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildMapView(),
                            _buildListView(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      bottomNavigationBar: AppBottomNav(
        userRole: widget.userRole,
        currentIndex: _getNavIndex(),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Container(margin: const EdgeInsets.all(16), child: Row(children: [Expanded(child: _buildStatCard(icon: Icons.location_city_rounded, label: 'Total', value: _stats['total'].toString(), gradient: const [Color(0xFF1976D2), Color(0xFF1565C0)])), const SizedBox(width: 10), Expanded(child: _buildStatCard(icon: Icons.check_circle_rounded, label: 'Normal', value: _stats['normal'].toString(), gradient: const [Color(0xFF4CAF50), Color(0xFF69F0AE)])), const SizedBox(width: 10), Expanded(child: _buildStatCard(icon: Icons.warning_rounded, label: 'Warning', value: _stats['warning'].toString(), gradient: const [Color(0xFFFF9800), Color(0xFFFFB74D)])), const SizedBox(width: 10), Expanded(child: _buildStatCard(icon: Icons.dangerous_rounded, label: 'Darurat', value: _stats['darurat'].toString(), gradient: const [Color(0xFFF44336), Color(0xFFEF5350)])),]));
  }

  Widget _buildStatCard({required IconData icon, required String label, required String value, required List<Color> gradient}) {
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]), child: Column(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 16)), const SizedBox(height: 6), TweenAnimationBuilder<int>(tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0), duration: const Duration(milliseconds: 1200), curve: Curves.easeOutCubic, builder: (context, val, child) => Text('$val', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)))), const SizedBox(height: 2), Text(label, style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey.shade600, fontWeight: FontWeight.w500), textAlign: TextAlign.center)]));
  }

  // ==========================================================================
  // 🔥🔥🔥 MAP VIEW — GOOGLE TILE + TOGGLE SATELIT/JALAN
  // ==========================================================================

  Widget _buildMapView() {
    final filtered = _filteredLocations;
    
    if (filtered.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade400)), const SizedBox(height: 16), Text('Tidak ada lokasi aktif', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade600))]));
    }

    final centerLat = filtered.map((l) => l['lat'] as double).reduce((a, b) => a + b) / filtered.length;
    final centerLng = filtered.map((l) => l['lng'] as double).reduce((a, b) => a + b) / filtered.length;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(centerLat, centerLng),
            initialZoom: 15.0,
            minZoom: 3.0,
            maxZoom: 21.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: (_, __) => setState(() => selectedLocation = null),
          ),
          children: [
            TileLayer(
              urlTemplate: _currentTileUrl,
              userAgentPackageName: 'com.pge.overtimeapp',
              maxZoom: 21,
              maxNativeZoom: 20,
              fallbackUrl: _fallbackUrl,
            ),
            
            PolylineLayer(
              polylines: _buildPolylines(),
            ),
            
            MarkerLayer(
              markers: filtered.map((location) {
                final isSelected = selectedLocation != null && selectedLocation!['id'] == location['id'];
                final isMoving = location['isMoving'] as bool? ?? false;
                final status = location['status'] as String;
                
                return Marker(
                  point: LatLng(location['lat'], location['lng']),
                  width: isSelected ? 80 : 60,
                  height: isSelected ? 90 : 70,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => selectedLocation = location);
                      _mapController.move(LatLng(location['lat'], location['lng']), 17.0);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (isMoving)
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) => Container(
                                  width: (isSelected ? 40 : 30) * (0.8 + _pulseController.value * 0.4),
                                  height: (isSelected ? 40 : 30) * (0.8 + _pulseController.value * 0.4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withValues(alpha: 0.15 * _pulseController.value),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            Container(
                              padding: EdgeInsets.all(isSelected ? 8 : 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _getStatusGradient(status),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: isSelected ? 2.5 : 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getStatusColor(status).withValues(alpha: 0.6),
                                    blurRadius: isSelected ? 12 : 8,
                                    spreadRadius: isSelected ? 2 : 1,
                                  ),
                                  BoxShadow(
                                    color: _getStatusColor(status).withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                status == 'Darurat' 
                                    ? Icons.dangerous_rounded 
                                    : status == 'Warning' 
                                        ? Icons.warning_rounded 
                                        : Icons.location_on_rounded,
                                color: Colors.white,
                                size: isSelected ? 20 : 16,
                              ),
                            ),
                            if (isMoving && location['heading'] != null)
                              Positioned(
                                top: -10,
                                child: Transform.rotate(
                                  angle: (location['heading'] as double) * pi / 180,
                                  child: Icon(
                                    Icons.navigation_rounded,
                                    color: _getStatusColor(status),
                                    size: isSelected ? 14 : 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          constraints: BoxConstraints(maxWidth: isSelected ? 80 : 60),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3)],
                          ),
                          child: Text(
                            location['name'] ?? 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSelected ? 10 : 8,
                              fontWeight: FontWeight.w700,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        
        // Toggle Satelit/Jalan
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              _buildMapToggleBtn(
                Icons.satellite_rounded,
                'Satelit',
                _isSatellite,
                () => setState(() => _isSatellite = true),
              ),
              const SizedBox(height: 6),
              _buildMapToggleBtn(
                Icons.map_rounded,
                'Jalan',
                !_isSatellite,
                () => setState(() => _isSatellite = false),
              ),
            ],
          ),
        ),
        
        // Tombol kontrol zoom & fit
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            children: [
              _mapButton(Icons.add_rounded, () {
                final currentZoom = _mapController.camera.zoom;
                _mapController.move(_mapController.camera.center, (currentZoom + 1).clamp(3.0, 21.0));
              }),
              const SizedBox(height: 6),
              _mapButton(Icons.remove_rounded, () {
                final currentZoom = _mapController.camera.zoom;
                _mapController.move(_mapController.camera.center, (currentZoom - 1).clamp(3.0, 21.0));
              }),
              const SizedBox(height: 6),
              _mapButton(Icons.my_location_rounded, () {
                _fitAllMarkers(filtered);
              }),
            ],
          ),
        ),

        // Info selected location
        if (selectedLocation != null)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: GestureDetector(
                      onTap: () => _showLocationDetail(selectedLocation!),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getStatusGradient(selectedLocation!['status']),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _getStatusColor(selectedLocation!['status']).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.touch_app_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(selectedLocation!['name'], style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Tap untuk detail', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                            _buildStatusChip(selectedLocation!['status']),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMapToggleBtn(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6366F1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : const Color(0xFF6366F1),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    int colorIndex = 0;
    for (final entry in _locationPaths.entries) {
      final path = entry.value;
      if (path.length < 2) continue;
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      polylines.add(Polyline(points: path, color: color.withValues(alpha: 0.1), strokeWidth: 8));
      polylines.add(Polyline(points: path, color: color.withValues(alpha: 0.5), strokeWidth: 3));
    }
    return polylines;
  }

  Widget _mapButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: const Color(0xFF1976D2))),
      ),
    );
  }

  void _fitAllMarkers(List<Map<String, dynamic>> locations) {
    if (locations.isEmpty) return;
    try {
      double minLat = locations.first['lat'] as double;
      double maxLat = locations.first['lat'] as double;
      double minLng = locations.first['lng'] as double;
      double maxLng = locations.first['lng'] as double;
      for (final loc in locations) {
        final lat = loc['lat'] as double;
        final lng = loc['lng'] as double;
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
      final bounds = LatLngBounds(LatLng(minLat - 0.005, minLng - 0.005), LatLng(maxLat + 0.005, maxLng + 0.005));
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
    } catch (e) {
      debugPrint('Fit marker error: $e');
    }
  }

  // ==========================================================================
  // LIST VIEW
  // ==========================================================================

  Widget _buildListView() {
    final filtered = _filteredLocations;
    if (filtered.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade400)), const SizedBox(height: 16), Text(_searchQuery.isNotEmpty ? 'Tidak ditemukan "$_searchQuery"' : 'Tidak ada lokasi', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade600))]));
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), itemCount: filtered.length, itemBuilder: (context, index) => _buildLocationCard(filtered[index], index));
  }

  Widget _buildLocationCard(Map<String, dynamic> location, int index) {
    return TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 400 + (index * 100)), curve: Curves.easeOutCubic, builder: (context, value, child) => Transform.translate(offset: Offset(0, 30 * (1 - value)), child: Opacity(opacity: value, child: Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: _getStatusColor(location['status']).withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))]), child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: () => _showLocationDetail(location), borderRadius: BorderRadius.circular(16), splashColor: const Color(0xFF1976D2).withValues(alpha: 0.05), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(gradient: LinearGradient(colors: _getStatusGradient(location['status'])), borderRadius: BorderRadius.circular(14)), child: Icon(location['status'] == 'Darurat' ? Icons.dangerous_rounded : location['status'] == 'Warning' ? Icons.warning_rounded : Icons.location_on_rounded, color: Colors.white, size: 24)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(location['name'], style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Row(children: [Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade500), const SizedBox(width: 4), Expanded(child: Text(location['address'], style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis))]), const SizedBox(height: 6), Row(children: [_buildMiniInfo(Icons.access_time_rounded, _getTimeAgo(location['lastUpdate'])), const SizedBox(width: 12), _buildMiniInfo(Icons.timer_rounded, _locationManager.getDurationShort()), const SizedBox(width: 12), _buildMiniInfo(Icons.battery_charging_full_rounded, location['battery'] ?? '--')])])), const SizedBox(width: 8), Column(children: [_buildStatusChip(location['status']), const SizedBox(height: 6), _buildMovementChip(location['isMoving'] as bool? ?? false), const SizedBox(height: 8), Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20)])]))))))));
  }
}

// ===========================================================================
// 🔥🔥🔥 MAP VIEW DIALOG — GOOGLE MAPS TILE + TOGGLE SATELIT
// ===========================================================================

class _MapViewDialog extends StatefulWidget {
  final double lat;
  final double lng;
  final String alamat;

  const _MapViewDialog({
    required this.lat,
    required this.lng,
    required this.alamat,
  });

  @override
  State<_MapViewDialog> createState() => _MapViewDialogState();
}

class _MapViewDialogState extends State<_MapViewDialog> {
  bool _isSatellite = true;

  static const String _satelliteUrl =
      'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
  static const String _streetUrl =
      'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

  String get _currentTileUrl => _isSatellite ? _satelliteUrl : _streetUrl;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(8),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(widget.lat, widget.lng),
                      initialZoom: 17.0,
                      minZoom: 5.0,
                      maxZoom: 21.0,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _currentTileUrl,
                        userAgentPackageName: 'com.pge.overtimeapp',
                        maxZoom: 21,
                        maxNativeZoom: 20,
                        fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(widget.lat, widget.lng),
                            width: 150,
                            height: 100,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '📍 Lokasi',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 6,
                                  color: Colors.red.withValues(alpha: 0.8),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 40,
                                  shadows: [
                                    Shadow(color: Colors.black38, blurRadius: 6),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Marker(
                            point: LatLng(widget.lat, widget.lng),
                            width: 80,
                            height: 80,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                  width: 2,
                                ),
                                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      children: [
                        _buildToggleBtn(
                          Icons.satellite_rounded,
                          'Satelit',
                          _isSatellite,
                          () => setState(() => _isSatellite = true),
                        ),
                        const SizedBox(height: 6),
                        _buildToggleBtn(
                          Icons.map_rounded,
                          'Jalan',
                          !_isSatellite,
                          () => setState(() => _isSatellite = false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleBtn(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6366F1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : const Color(0xFF6366F1)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isSatellite ? Icons.satellite_rounded : Icons.map_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lokasi',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isSatellite ? '🛰️ Satelit' : '🛣️ Jalan',
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          if (widget.alamat.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.alamat,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white70,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${widget.lat.toStringAsFixed(6)}, ${widget.lng.toStringAsFixed(6)}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSatellite
                  ? 'Tampilan satelit • Tap tombol untuk ganti ke peta jalan'
                  : 'Tampilan jalan • Tap tombol untuk ganti ke satelit',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final encodedLabel = Uri.encodeComponent(widget.alamat);
                final uri = Uri.parse(
                  'https://www.google.com/maps?q=${widget.lat},${widget.lng}($encodedLabel)',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.open_in_browser_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Google Maps',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// ANIMATED BUILDER
// =========================

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Listenable animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}