// lib/features/shared/widgets/location_monitoring.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '/core/services/live_location_service.dart';
import '/core/services/live_location_manager.dart';

class LocationMonitoring extends StatefulWidget {
  final String? userRole;
  final String? mitraId;
  
  const LocationMonitoring({
    super.key,
    this.userRole,
    this.mitraId,
  });

  @override
  State<LocationMonitoring> createState() => _LocationMonitoringState();
}

class _LocationMonitoringState extends State<LocationMonitoring>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final MapController _mapController;

  final LiveLocationService _locationService = LiveLocationService();
  final LiveLocationManager _locationManager = LiveLocationManager();

  bool _disposed = false;
  List<LiveLocationData> _lastLocations = [];
  DateTime _lastRefresh = DateTime.now();
  Timer? _refreshTimer;

  Map<String, LiveLocationData> _liveLocations = {};
  Map<String, AnimationController> _pulseAnimations = {};
  Map<String, AnimationController> _blinkAnimations = {};
  bool _isLoading = true;
  bool _mapReady = false;

  bool _isSatellite = true;

  VoidCallback? _locationListener;

  bool get _isSuperAdmin => widget.userRole == 'superadmin';
  bool get _isHSSE => widget.userRole == 'manager_hsse';
  bool get _isManager => widget.userRole == 'manager';
  bool get _isPengawas => widget.userRole == 'pengawas';

  static const String _satelliteUrl =
      'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
  static const String _streetUrl =
      'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  static const String _fallbackUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  String get _currentTileUrl => _isSatellite ? _satelliteUrl : _streetUrl;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && mounted) {
        _mapReady = true;
        _setupRealtimeListener();
        _startAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    if (_locationListener != null) {
      _locationService.removeListener(_locationListener!);
      _locationListener = null;
    }
    _locationService.stopListening();
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _pulseAnimations.values) {
      controller.dispose();
    }
    _pulseAnimations.clear();
    for (final controller in _blinkAnimations.values) {
      controller.dispose();
    }
    _blinkAnimations.clear();
    super.dispose();
  }

  void _setupRealtimeListener() {
    if (_locationListener != null) {
      _locationService.removeListener(_locationListener!);
      _locationListener = null;
    }
    _locationService.stopListening();
    _locationService.listenToAllActiveLocations();

    _locationListener = () {
      if (!_disposed && mounted) {
        _processNewLocations();
      }
    };

    _locationService.addListener(_locationListener!);
    _processNewLocations();
  }

  void _processNewLocations() {
    if (_disposed || !mounted) return;

    try {
      Map<String, LiveLocationData> newLocations = Map.from(_locationService.latestLocations);

      if (!_isSuperAdmin) {
        newLocations = _filterLocationsByRole(newLocations);
      }

      for (final entry in newLocations.entries) {
        final userId = entry.key;
        if (!_pulseAnimations.containsKey(userId)) {
          _setupAnimations(userId);
        }
      }

      _pulseAnimations.keys
          .where((key) => !newLocations.containsKey(key))
          .toList()
          .forEach((key) {
        _pulseAnimations[key]?.dispose();
        _pulseAnimations.remove(key);
        _blinkAnimations[key]?.dispose();
        _blinkAnimations.remove(key);
      });

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && mounted) {
            setState(() {
              _liveLocations = Map.from(newLocations);
              _isLoading = false;
              _lastRefresh = DateTime.now();
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing locations: $e');
    }
  }

  Map<String, LiveLocationData> _filterLocationsByRole(Map<String, LiveLocationData> locations) {
    final filtered = <String, LiveLocationData>{};
    
    for (final entry in locations.entries) {
      final location = entry.value;
      
      if (_isSuperAdmin) {
        filtered[entry.key] = location;
      } else if (_isManager || _isHSSE) {
        if (location.userRole != 'superadmin') {
          filtered[entry.key] = location;
        }
      } else if (_isPengawas) {
        if (location.userRole == 'mitra') {
          filtered[entry.key] = location;
        }
      } else {
        filtered[entry.key] = location;
      }
    }
    
    return filtered;
  }

  void _setupAnimations(String userId) {
    try {
      final pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );
      pulseController.repeat(reverse: true);
      _pulseAnimations[userId] = pulseController;

      final blinkController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      blinkController.repeat(reverse: true);
      _blinkAnimations[userId] = blinkController;
    } catch (e) {
      debugPrint('Error setting up animations: $e');
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (!_disposed && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_disposed && mounted) {
              setState(() {
                _lastRefresh = DateTime.now();
              });
            }
          });
        }
      },
    );
  }

  void _scheduleAutoFit(List<LiveLocationData> locations) {
    if (locations.isEmpty || !_mapReady || _disposed) return;

    bool changed = _lastLocations.length != locations.length;
    if (!changed) {
      for (int i = 0; i < locations.length; i++) {
        final a = _lastLocations[i];
        final b = locations[i];
        if (a.userName != b.userName ||
            a.latitude != b.latitude ||
            a.longitude != b.longitude) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) return;

    _lastLocations = locations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && mounted && _mapReady) {
        _fitAllMarkers(locations);
      }
    });
  }

  void _fitAllMarkers(List<LiveLocationData> locations) {
    if (locations.isEmpty || !_mapReady || _disposed) return;

    try {
      double minLat = locations.first.latitude;
      double maxLat = locations.first.latitude;
      double minLng = locations.first.longitude;
      double maxLng = locations.first.longitude;

      for (final loc in locations) {
        if (loc.latitude < minLat) minLat = loc.latitude;
        if (loc.latitude > maxLat) maxLat = loc.latitude;
        if (loc.longitude < minLng) minLng = loc.longitude;
        if (loc.longitude > maxLng) maxLng = loc.longitude;
      }

      if (locations.length == 1) {
        _mapController.move(
          LatLng(locations.first.latitude, locations.first.longitude),
          16,
        );
        return;
      }

      final bounds = LatLngBounds(
        LatLng(minLat, minLng),
        LatLng(maxLat, maxLng),
      );

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
        ),
      );
    } catch (e) {
      debugPrint('Fit marker error: $e');
    }
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
    if (!loc.isActive) return 'Tracking tidak aktif';
    final diff = DateTime.now().difference(loc.timestamp);
    if (diff.inMinutes > 30) return 'Tidak ada update > 30 menit';
    if (diff.inMinutes > 10) return 'Update terakhir > 10 menit';
    final battery = loc.batteryLevel ?? 100;
    if (battery < 15) return 'Battery kritis (${battery.toStringAsFixed(0)}%)';
    if (battery < 30) return 'Battery rendah (${battery.toStringAsFixed(0)}%)';
    return null;
  }

  String _getRoleLabel(LiveLocationData location) {
    if (location.userRole == 'superadmin') return 'Super Admin';
    if (location.userRole == 'manager') return 'Manager';
    if (location.userRole == 'pengawas') return 'Pengawas';
    if (location.userRole == 'manager_hsse') return 'HSSE';
    if (location.userRole == 'mitra') {
      if (location.userFungsi == 'lembur') return 'Lembur';
      if (location.userFungsi == 'pekerja') return 'Pekerja';
      return 'Mitra';
    }
    return location.userRole ?? 'User';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final mapHeight = screenWidth < 400 ? 350.0 : 420.0;
    final cardHeight = screenWidth < 360 ? 130.0 : 150.0;

    final locations = _liveLocations.values.toList();

    final alertCount = locations.where((l) {
      final status = _determineStatus(l);
      return status == 'Warning' || status == 'Darurat';
    }).length;

    if (locations.isNotEmpty && _mapReady && !_disposed) {
      _scheduleAutoFit(locations);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.blue.shade50.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isLoading
          ? _buildLoadingState(mapHeight)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(locations.length, alertCount),
                const SizedBox(height: 12),
                if (locations.isEmpty)
                  _buildEmptyState(mapHeight)
                else ...[
                  _buildMap(locations, mapHeight),
                  const SizedBox(height: 12),
                  _buildLegend(),
                  const SizedBox(height: 10),
                  _buildLocationCards(locations, cardHeight),
                ],
              ],
            ),
    );
  }

  // 🔥🔥🔥 HEADER 2 BARIS — JUDUL WRAP KE BAWAH
  Widget _buildHeader(int activeCount, int alertCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.08),
            Colors.blue.shade50.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon lokasi
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 10),
          // Judul + Badge dalam Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Baris 1: Judul (bisa wrap 2 baris)
                const Text(
                  'Pantau Lokasi Lembur Mitra',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Baris 2: Badge status
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusBadge(
                      icon: Icons.person,
                      label: '$activeCount Aktif',
                      color: Colors.green,
                      isAlert: false,
                    ),
                    if (alertCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildStatusBadge(
                        icon: Icons.warning_amber_rounded,
                        label: '$alertCount Alert',
                        color: Colors.red,
                        isAlert: true,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isAlert,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isAlert ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LivePulse(isAlert: isAlert, color: color),
          const SizedBox(width: 4),
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          _legendItem(Colors.green, 'Normal', Icons.check_circle),
          _legendItem(Colors.orange, 'Warning', Icons.warning_amber_rounded),
          _legendItem(Colors.red, 'Darurat', Icons.emergency),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildMap(List<LiveLocationData> locations, double height) {
    if (locations.isEmpty) return _buildEmptyState(height);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(locations.first.latitude, locations.first.longitude),
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 21,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _currentTileUrl,
                userAgentPackageName: 'com.pge.overtimeapp',
                tileProvider: CancellableNetworkTileProvider(),
                maxZoom: 21,
                maxNativeZoom: 20,
                fallbackUrl: _fallbackUrl,
                panBuffer: 2,
                keepBuffer: 5,
              ),
              MarkerLayer(
                markers: locations.map((location) {
                  final status = _determineStatus(location);
                  final point = LatLng(location.latitude, location.longitude);
                  final userId = location.userId;
                  return Marker(
                    point: point,
                    width: 60,
                    height: 70,
                    child: GestureDetector(
                      onTap: () {
                        if (!_disposed && mounted) {
                          _showDetail(location, status);
                          _mapController.move(point, 17);
                        }
                      },
                      child: _buildCompactMarker(location, status, userId),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
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
          Positioned(
            right: 10,
            bottom: 10,
            child: Column(
              children: [
                _mapControlButton(Icons.add, () {
                  if (!_disposed) {
                    final current = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, current + 1);
                  }
                }),
                const SizedBox(height: 6),
                _mapControlButton(Icons.remove, () {
                  if (!_disposed) {
                    final current = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, current - 1);
                  }
                }),
                const SizedBox(height: 6),
                _mapControlButton(Icons.my_location, () {
                  if (!_disposed && locations.isNotEmpty) {
                    _fitAllMarkers(locations);
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapToggleBtn(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6366F1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
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
              Icon(icon, size: 14, color: isActive ? Colors.white : const Color(0xFF6366F1)),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
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

  Widget _buildCompactMarker(LiveLocationData location, String status, String userId) {
    final isAlert = status == 'Warning' || status == 'Darurat';
    final blinkController = _blinkAnimations[userId];
    final markerColor = isAlert ? Colors.red : AppColors.primaryBlue;
    
    if (blinkController == null) {
      return _buildSimpleCompactMarker(location, status, isAlert, markerColor);
    }

    return AnimatedBuilder(
      listenable: blinkController,
      builder: (context, child) {
        final blinkValue = blinkController.value;
        return _buildSimpleCompactMarker(
          location, status, isAlert, markerColor, blinkValue,
        );
      },
    );
  }

  Widget _buildSimpleCompactMarker(
    LiveLocationData location,
    String status,
    bool isAlert,
    Color markerColor, [
    double blinkValue = 1.0,
  ]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: (isAlert ? Colors.red : markerColor).withValues(alpha: 0.4 * blinkValue),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            isAlert ? Icons.warning_rounded : Icons.person,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(color: markerColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            location.userName.length > 10 
                ? '${location.userName.substring(0, 9)}...' 
                : location.userName,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: markerColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: isAlert ? Colors.red : Colors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isAlert ? Colors.red : Colors.green).withValues(alpha: 0.5 * blinkValue),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapControlButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 4,
      shadowColor: Colors.blue.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryBlue),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Darurat': return Colors.red;
      case 'Warning': return Colors.orange;
      case 'Normal': return Colors.green;
      default: return AppColors.primaryBlue;
    }
  }

  Widget _buildLocationCards(List<LiveLocationData> locations, double height) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: locations.length,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemBuilder: (context, index) {
          final location = locations[index];
          final status = _determineStatus(location);
          final color = _getStatusColor(status);
          final batteryLevel = location.batteryLevel;
          final warning = _getWarningMessage(location);
          final userId = location.userId;
          final blinkController = _blinkAnimations[userId];
          final cardColor = AppColors.primaryBlue;

          if (blinkController == null) {
            return _buildCardContent(location, status, color, cardColor, batteryLevel, warning, 1.0);
          }

          return AnimatedBuilder(
            listenable: blinkController,
            builder: (context, child) {
              return _buildCardContent(
                location, status, color, cardColor, batteryLevel, warning, blinkController.value,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCardContent(
    LiveLocationData location,
    String status,
    Color color,
    Color cardColor,
    double? batteryLevel,
    String? warning,
    double blinkValue,
  ) {
    final roleLabel = _getRoleLabel(location);

    return GestureDetector(
      onTap: () {
        _showDetail(location, status);
        _mapController.move(LatLng(location.latitude, location.longitude), 17);
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, cardColor.withValues(alpha: 0.04)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardColor.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: cardColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: status == 'Normal' ? Colors.green : color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withValues(alpha: 0.5 * blinkValue),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cardColor),
                  ),
                ),
                if (status != 'Normal')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: status == 'Darurat' ? Colors.red : Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(Icons.badge_outlined, roleLabel, cardColor),
            const SizedBox(height: 4),
            if (batteryLevel != null) _batteryIndicator(batteryLevel),
            if (warning != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(warning, style: TextStyle(fontSize: 9, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            Text(
              _formatTimeAgo(location.timestamp),
              style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _batteryIndicator(double batteryLevel) {
    final batteryColor = batteryLevel > 50 ? Colors.green : batteryLevel > 20 ? Colors.orange : Colors.red;
    return Row(
      children: [
        Icon(
          batteryLevel > 50 ? Icons.battery_full : batteryLevel > 20 ? Icons.battery_4_bar : Icons.battery_alert,
          size: 12,
          color: batteryColor,
        ),
        const SizedBox(width: 4),
        Text('${batteryLevel.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: batteryColor)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: batteryLevel / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(double height) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Memuat lokasi...', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(double height) {
    String message = 'Belum ada lokasi aktif';

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Lokasi muncul saat user mulai tracking', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showDetail(LiveLocationData location, String status) {
    final color = _getStatusColor(status);
    final warning = _getWarningMessage(location);
    final roleLabel = _getRoleLabel(location);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(location.userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _statusChip(status, color),
                              const SizedBox(width: 8),
                              _statusChip(roleLabel, _getRoleColorForLabel(roleLabel)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailCard(Icons.location_on, location.address ?? '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}'),
                const SizedBox(height: 16),
                _buildInfoGrid(location),
                if (warning != null) ...[
                  const SizedBox(height: 12),
                  _warningCard(warning),
                ],
                const SizedBox(height: 20),
                _buildLokasiOptions(location),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLokasiOptions(LiveLocationData location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lihat Lokasi',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]),
        ),
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
                    location.latitude,
                    location.longitude,
                    location.address ?? 'Lokasi ${location.userName}',
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildLokasiOptionButton(
                icon: Icons.open_in_browser_rounded,
                label: 'Google Maps',
                subtitle: 'Buka aplikasi',
                color: Colors.green,
                onTap: () {
                  _launchMaps(location.latitude, location.longitude);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

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
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  void _showLokasiOnMap(double lat, double lng, String alamat) {
    showDialog(
      context: context,
      builder: (ctx) => _MapViewDialog(lat: lat, lng: lng, alamat: alamat),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }

  Widget _detailCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 12))),
        ],
      ),
    );
  }

  Widget _warningCard(String warning) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(warning, style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(LiveLocationData location) {
    final items = <MapEntry<String, dynamic>>[];
    items.add(MapEntry('Durasi', _locationManager.getDurationShort()));
    if (location.userFungsi != null) items.add(MapEntry('Fungsi', location.userFungsi!));
    if (location.batteryLevel != null) items.add(MapEntry('Battery', '${location.batteryLevel!.toStringAsFixed(0)}%'));
    if (location.speed != null) items.add(MapEntry('Kecepatan', '${location.speed!.toStringAsFixed(1)} m/s'));
    items.add(MapEntry('Update', _formatTimeAgo(location.timestamp)));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(_getIconForLabel(item.key), size: 14, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.key, style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Text('${item.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Durasi': return Icons.timer;
      case 'Fungsi': return Icons.work;
      case 'Battery': return Icons.battery_full;
      case 'Kecepatan': return Icons.speed;
      case 'Update': return Icons.access_time;
      default: return Icons.info;
    }
  }

  Color _getRoleColorForLabel(String label) {
    if (label.contains('Super Admin')) return Colors.purple;
    if (label.contains('HSSE')) return Colors.teal;
    if (label.contains('Manager')) return Colors.blue;
    if (label.contains('Pengawas')) return Colors.orange;
    return Colors.grey;
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bln';
    if (diff.inDays > 0) return '${diff.inDays} hr';
    if (diff.inHours > 0) return '${diff.inHours} jam';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mnt';
    return 'baru saja';
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
        );
      }
    }
  }
}

// ===========================================================================
// 🔥🔥🔥 MAP VIEW DIALOG
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
      backgroundColor: Colors.white,
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
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: const Text('📍 Lokasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                ),
                                Container(width: 2, height: 6, color: Colors.red.withValues(alpha: 0.8)),
                                const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 40, shadows: [Shadow(color: Colors.black38, blurRadius: 6)]),
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
                                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 2),
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
                        _buildToggleBtn(Icons.satellite_rounded, 'Satelit', _isSatellite, () => setState(() => _isSatellite = true)),
                        const SizedBox(height: 6),
                        _buildToggleBtn(Icons.map_rounded, 'Jalan', !_isSatellite, () => setState(() => _isSatellite = false)),
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6366F1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isActive ? Colors.white : const Color(0xFF6366F1)),
              const SizedBox(width: 3),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF6366F1))),
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
        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_isSatellite ? Icons.satellite_rounded : Icons.map_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Lokasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(_isSatellite ? '🛰️ Satelit' : '🛣️ Jalan', style: TextStyle(fontSize: 9, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          if (widget.alamat.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.alamat, style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 4),
          Text('${widget.lat.toStringAsFixed(6)}, ${widget.lng.toStringAsFixed(6)}', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey[50], border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSatellite ? 'Tampilan satelit • Tap tombol untuk ganti ke peta jalan' : 'Tampilan jalan • Tap tombol untuk ganti ke satelit',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final encodedLabel = Uri.encodeComponent(widget.alamat);
                final uri = Uri.parse('https://www.google.com/maps?q=${widget.lat},${widget.lng}($encodedLabel)');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_browser_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Google Maps', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
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
    required Listenable listenable,
    required this.builder,
    this.child,
  }) : super(listenable: listenable);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

// =========================
// LIVE PULSE WIDGET
// =========================

class _LivePulse extends StatefulWidget {
  final bool isAlert;
  final Color color;
  const _LivePulse({required this.isAlert, required this.color});

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      listenable: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4 * _animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}