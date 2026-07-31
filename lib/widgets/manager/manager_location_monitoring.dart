// lib/widgets/manager/manager_location_monitoring.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ManagerLocationMonitoring extends StatefulWidget {
  final String fungsi;
  final List<Map<String, dynamic>> initialLocations;

  const ManagerLocationMonitoring({
    super.key,
    required this.fungsi,
    this.initialLocations = const [],
  });

  @override
  State<ManagerLocationMonitoring> createState() => _ManagerLocationMonitoringState();
}

class _ManagerLocationMonitoringState extends State<ManagerLocationMonitoring>
    with SingleTickerProviderStateMixin {
  
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _onlineCount = 0;
  int _offlineCount = 0;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  late MapController _mapController;
  bool _mapReady = false;
  
  StreamSubscription<QuerySnapshot>? _locationSubscription;
  Timer? _refreshTimer;

  // 🔵 Warna Manager (Pertamina Branding)
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color accentColor = Color(0xFF42A5F5);
  static const Color successColor = Color(0xFF43A047);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color dangerColor = Color(0xFFEF5350);
  static const Color infoColor = Color(0xFF29B6F6);

  static const Color bgPrimary = Color(0xFFF5F9FF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color textTertiary = Color(0xFF90A4AE);
  static const Color borderLight = Color(0xFFE3E8F0);

  @override
  void initState() {
    super.initState();
    
    _mapController = MapController();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    
    if (widget.initialLocations.isNotEmpty) {
      _locations = widget.initialLocations;
      _updateCounts();
      _isLoading = false;
      _fadeController.forward();
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapReady = true;
      _setupRealtimeListener();
      _startAutoRefresh();
    });
  }

  void _updateCounts() {
    _onlineCount = _locations.where((l) => l['isOnline'] == true).length;
    _offlineCount = _locations.where((l) => l['isOnline'] != true).length;
  }

  void _setupRealtimeListener() {
    if (widget.fungsi.isEmpty) return;

    _locationSubscription?.cancel();
    _locationSubscription = FirebaseFirestore.instance
        .collection('live_locations')
        .where('fungsi', isEqualTo: widget.fungsi)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final locations = snapshot.docs.map((doc) {
        final d = doc.data();
        double lat = 0, lng = 0;
        final geo = d['coordinates'];
        if (geo is GeoPoint) {
          lat = geo.latitude;
          lng = geo.longitude;
        } else {
          lat = (d['latitude'] as num?)?.toDouble() ?? 0;
          lng = (d['longitude'] as num?)?.toDouble() ?? 0;
        }
        
        return {
          'id': doc.id,
          'name': d['user_name'] ?? d['name'] ?? 'Unknown',
          'lat': lat,
          'lng': lng,
          'status': d['status'] ?? 'Normal',
          'address': d['address'] ?? '',
          'lastUpdate': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'workers': d['workers'] ?? 1,
          'battery': d['battery'] ?? 100,
          'signal': d['signal'] ?? '--',
          'role': d['role'] ?? 'mitra',
          'fungsi': d['fungsi'] ?? '',
          'isOnline': d['isOnline'] ?? true,
          'user_id': d['user_id'] ?? '',
        };
      }).toList();

      setState(() {
        _locations = locations;
        _updateCounts();
        _isLoading = false;
        _hasError = false;
      });

      _fadeController.reset();
      _fadeController.forward();

      if (_locations.isNotEmpty && _mapReady) {
        _fitAllMarkers();
      }

    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = error.toString();
        });
      }
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted) return;
        setState(() {});
      },
    );
  }

  void _fitAllMarkers() {
    if (_locations.isEmpty || !_mapReady) return;

    try {
      double minLat = _locations.first['lat'] as double;
      double maxLat = _locations.first['lat'] as double;
      double minLng = _locations.first['lng'] as double;
      double maxLng = _locations.first['lng'] as double;

      for (final loc in _locations) {
        final lat = loc['lat'] as double;
        final lng = loc['lng'] as double;
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }

      if (_locations.length == 1) {
        _mapController.move(
          LatLng(_locations.first['lat'] as double, _locations.first['lng'] as double),
          15,
        );
        return;
      }

      final latPadding = (maxLat - minLat) * 0.5;
      final lngPadding = (maxLng - minLng) * 0.5;

      final bounds = LatLngBounds(
        LatLng(minLat - latPadding, minLng - lngPadding),
        LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (e) {
      debugPrint('Fit marker error: $e');
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bln';
    if (diff.inDays > 0) return '${diff.inDays} hr';
    if (diff.inHours > 0) return '${diff.inHours} jam';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mnt';
    return 'br saja';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'normal':
      case 'active':
        return successColor;
      case 'warning':
      case 'pending':
        return warningColor;
      case 'offline':
      case 'error':
      case 'critical':
        return dangerColor;
      default:
        return Colors.grey;
    }
  }

  Color _getBatteryColor(double battery) {
    if (battery > 50) return successColor;
    if (battery > 20) return warningColor;
    return dangerColor;
  }

  String _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'normal':
      case 'active':
        return '🟢';
      case 'warning':
      case 'pending':
        return '🟡';
      case 'offline':
      case 'error':
      case 'critical':
        return '🔴';
      default:
        return '⚪';
    }
  }

  bool _isRecent(DateTime time) {
    return DateTime.now().difference(time).inMinutes < 10;
  }

  void _showDetail(Map<String, dynamic> location) {
    final isOnline = location['isOnline'] ?? true;
    final status = isOnline ? 'Online' : 'Offline';
    final statusColor = isOnline ? successColor : Colors.grey;
    final lastUpdate = location['lastUpdate'] as DateTime? ?? DateTime.now();
    final battery = (location['battery'] as num?)?.toDouble() ?? 100;
    final isRecent = _isRecent(lastUpdate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [surfaceColor, bgPrimary],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, accentColor],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [statusColor, statusColor.withValues(alpha: 0.6)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (location['name']?.toString().isNotEmpty ?? false)
                              ? location['name'][0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isRecent ? statusColor : Colors.grey,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    if (isRecent)
                                      BoxShadow(
                                        color: statusColor.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isRecent ? status : 'Offline',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isRecent ? statusColor : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  location['role']?.toString().toUpperCase() ?? 'MITRA',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Info Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.4,
                      children: [
                        _buildInfoTile(
                          icon: Icons.access_time_rounded,
                          label: 'Update',
                          value: _getTimeAgo(lastUpdate),
                          color: isRecent ? primaryColor : Colors.grey,
                        ),
                        _buildInfoTile(
                          icon: Icons.battery_full_rounded,
                          label: 'Battery',
                          value: '${battery.toStringAsFixed(0)}%',
                          color: _getBatteryColor(battery),
                        ),
                        _buildInfoTile(
                          icon: Icons.signal_cellular_alt_rounded,
                          label: 'Signal',
                          value: location['signal'] ?? '--',
                          color: primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Address
                    if (location['address'] != null && location['address'].toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderLight),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                location['address'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchMaps(
                              location['lat'] as double,
                              location['lng'] as double,
                            ),
                            icon: const Icon(Icons.map_rounded, size: 20),
                            label: const Text(
                              'Buka Maps',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location, int index) {
    final isOnline = location['isOnline'] ?? true;
    final statusColor = isOnline ? successColor : Colors.grey;
    final lastUpdate = location['lastUpdate'] as DateTime? ?? DateTime.now();
    final isRecent = _isRecent(lastUpdate);
    final battery = (location['battery'] as num?)?.toDouble() ?? 100;
    final batteryColor = _getBatteryColor(battery);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showDetail(location),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRecent && isOnline 
                  ? primaryColor.withValues(alpha: 0.2) 
                  : borderLight,
              width: isRecent && isOnline ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isRecent && isOnline 
                    ? primaryColor.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Status Indicator
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecent && isOnline ? statusColor : Colors.grey.shade300,
                  boxShadow: [
                    if (isRecent && isOnline)
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.1),
                      accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(
                    color: isRecent && isOnline 
                        ? primaryColor.withValues(alpha: 0.2) 
                        : borderLight,
                  ),
                ),
                child: Center(
                  child: Text(
                    (location['name']?.toString().isNotEmpty ?? false)
                        ? location['name'][0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isRecent && isOnline ? primaryColor : textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            location['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (location['role'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              location['role'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _getStatusIcon(location['status'] ?? 'Normal'),
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isRecent && isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isRecent && isOnline ? statusColor : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeAgo(lastUpdate),
                          style: TextStyle(
                            fontSize: 10,
                            color: textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Battery
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        battery > 50 
                            ? Icons.battery_full_rounded 
                            : battery > 20 
                                ? Icons.battery_4_bar_rounded 
                                : Icons.battery_alert_rounded,
                        size: 14,
                        color: batteryColor,
                      ),
                      Text(
                        '${battery.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location['signal'] ?? '--',
                    style: TextStyle(
                      fontSize: 10,
                      color: textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Stats
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryColor, accentColor],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pemantauan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (_locations.isNotEmpty) ...[
                        _buildStatChip(
                          label: '$_onlineCount Online',
                          color: successColor,
                          icon: Icons.circle_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildStatChip(
                          label: '$_offlineCount Offline',
                          color: Colors.grey,
                          icon: Icons.circle_rounded,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_locations.length} Total',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Belum ada lokasi',
                          style: TextStyle(
                            fontSize: 11,
                            color: textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Refresh indicator
            AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return Opacity(
                  opacity: _isLoading ? 0.5 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderLight),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            color: textSecondary,
                            size: 18,
                          ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Content
        if (_isLoading)
          _buildLoadingState()
        else if (_hasError)
          _buildErrorState()
        else if (_locations.isEmpty)
          _buildEmptyState()
        else
          _buildLocationList(),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Memuat lokasi tim...',
            style: TextStyle(
              fontSize: 12,
              color: textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dangerColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dangerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: dangerColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Gagal memuat lokasi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: dangerColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _errorMessage ?? 'Terjadi kesalahan',
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              surfaceColor,
              bgPrimary,
              primaryColor.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderLight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon dengan gradient background
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.08),
                    accentColor.withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.location_off_rounded,
                size: 56,
                color: textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            const Text(
              'Belum Ada Lokasi Aktif',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Tunggu tim Anda online dan bagikan lokasi',
              style: TextStyle(
                fontSize: 13,
                color: textTertiary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
        
          ],
        ),
      ),
    );
  }

  Widget _buildLocationList() {
    // Urutkan: online dulu, lalu berdasarkan waktu update terbaru
    final sortedLocations = List<Map<String, dynamic>>.from(_locations)
      ..sort((a, b) {
        final aOnline = a['isOnline'] ?? false;
        final bOnline = b['isOnline'] ?? false;
        if (aOnline && !bOnline) return -1;
        if (!aOnline && bOnline) return 1;
        
        final aTime = a['lastUpdate'] as DateTime? ?? DateTime.now();
        final bTime = b['lastUpdate'] as DateTime? ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: bgPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: sortedLocations.map((location) {
            return _buildLocationCard(location, sortedLocations.indexOf(location));
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Maps'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }
}