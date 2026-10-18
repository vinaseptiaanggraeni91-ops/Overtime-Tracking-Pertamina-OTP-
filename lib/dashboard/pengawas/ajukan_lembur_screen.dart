// lib/features/pengawas/lembur/ajukan_lembur_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '/core/services/overtime_service.dart';
import '/core/services/notification_service.dart';
import '/core/services/location_service.dart';
import '/core/services/mitra_limit_service.dart';
import '/widgets/rate_info_card.dart';
import '/widgets/ajukan_lembur/header_profile_card.dart';
import '/widgets/ajukan_lembur/progress_stepper.dart';
import '/widgets/ajukan_lembur/mitra_section.dart';
import '/widgets/ajukan_lembur/waktu_section.dart';
import '/widgets/ajukan_lembur/lokasi_section.dart';
import '/widgets/ajukan_lembur/alasan_section.dart';
import '/widgets/ajukan_lembur/urgensi_section.dart';
import '/widgets/ajukan_lembur/budget_breakdown_section.dart';
import '/widgets/ajukan_lembur/submit_button.dart';
import '/widgets/ajukan_lembur/map_picker_page.dart';
import '/widgets/ajukan_lembur/mitra_selection_dialog.dart';
import '/widgets/ajukan_lembur/preview_dialog.dart';
import '/widgets/bottom_nav/pengawas_bottom_nav.dart';

// ==================== PARTICLE CLASS ====================
class _ConfettiParticle {
  final Color color;
  final double left;
  final Duration delay;
  final double size;
  final double rotation;
  final double speed;

  _ConfettiParticle({
    required this.color,
    required this.left,
    required this.delay,
    required this.size,
    required this.rotation,
    required this.speed,
  });
}

// ==================== SUCCESS DIALOG CONTENT ====================
class _SuccessDialogContent extends StatefulWidget {
  final String groupId;
  final int validMirasCount;
  final bool isMultiDay;
  final bool isOvernight;
  final String? namaPengawas;
  final String? fungsiPengawas;
  final String Function(double) formatRupiah;
  final double totalBiayaLembur;
  final VoidCallback onSelesai;

  const _SuccessDialogContent({
    required this.groupId,
    required this.validMirasCount,
    required this.isMultiDay,
    required this.isOvernight,
    this.namaPengawas,
    this.fungsiPengawas,
    required this.formatRupiah,
    required this.totalBiayaLembur,
    required this.onSelesai,
  });

  @override
  State<_SuccessDialogContent> createState() => _SuccessDialogContentState();
}

class _SuccessDialogContentState extends State<_SuccessDialogContent>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _confettiController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late List<_ConfettiParticle> _particles;

  bool _showContent = false;
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _particles = _generateConfettiParticles();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _showParticles = true);
        _confettiController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _showContent = true);
        _slideController.forward();
      }
    });
  }

  List<_ConfettiParticle> _generateConfettiParticles() {
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final particles = <_ConfettiParticle>[];
    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFE66D),
      const Color(0xFF95E1D3),
      const Color(0xFFF38181),
      const Color(0xFFAA96DA),
      const Color(0xFF74B9FF),
      const Color(0xFFA8E6CF),
      const Color(0xFFFF8A80),
      const Color(0xFFB388FF),
    ];

    for (int i = 0; i < 50; i++) {
      particles.add(_ConfettiParticle(
        color: colors[i % colors.length],
        left: random.nextDouble(),
        delay: Duration(milliseconds: random.nextInt(600)),
        size: 5.0 + random.nextDouble() * 8,
        rotation: random.nextDouble() * 2 * pi,
        speed: 0.5 + random.nextDouble() * 1.5,
      ));
    }
    return particles;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              elevation: 24,
              shadowColor: const Color(0xFF1976D2).withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 52, 24, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Color(0xFFF5F8FF)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: _slideAnimation.value,
                      child: Opacity(
                        opacity: _showContent ? 1.0 : 0.0,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade400, Colors.green.shade600],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'SUKSES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF2196F3)],
                        ).createShader(bounds),
                        child: const Text(
                          'Pengajuan Berhasil! 🎉',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lembur berhasil diajukan oleh',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1976D2).withValues(alpha: 0.1),
                              const Color(0xFF2196F3).withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF1976D2).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: const Color(0xFF1976D2).withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.namaPengawas ?? 'Pengawas',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF1976D2).withValues(alpha: 0.12),
                                  const Color(0xFF2196F3).withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF1976D2).withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1976D2).withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ID PENGAJUAN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade600,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF1976D2).withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.tag_rounded,
                                        size: 16,
                                        color: const Color(0xFF1976D2).withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 8),
                                      SelectableText(
                                        widget.groupId,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1565C0),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 18,
                                          color: Color(0xFF1976D2),
                                        ),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('ID berhasil disalin!'),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              duration: const Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        splashRadius: 16,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Simpan ID ini untuk referensi',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.people_alt_rounded,
                              label: 'Total TAD',
                              value: '${widget.validMirasCount} Orang',
                              color: const Color(0xFF1976D2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Estimasi Biaya',
                              value: widget.formatRupiah(widget.totalBiayaLembur),
                              color: const Color(0xFF43A047),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.isMultiDay || widget.isOvernight)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              if (widget.isMultiDay)
                                _buildTag(
                                  icon: Icons.calendar_view_week_rounded,
                                  text: 'Multi-Hari',
                                  color: Colors.purple,
                                ),
                              if (widget.isOvernight)
                                _buildTag(
                                  icon: Icons.nights_stay_rounded,
                                  text: 'Lintas Malam',
                                  color: Colors.indigo,
                                ),
                              _buildTag(
                                icon: Icons.notifications_active_rounded,
                                text: 'Notifikasi Terkirim',
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.hourglass_bottom_rounded,
                                size: 22,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Menunggu Persetujuan Manager',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Pengajuan akan segera ditinjau',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade600,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onSelesai,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 6,
                            shadowColor: const Color(0xFF1976D2).withValues(alpha: 0.4),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'SELESAI',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -40,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF43A047), Color(0xFF66BB6A), Color(0xFF81C784)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 48),
                      Positioned(
                        top: 14,
                        right: 18,
                        child: Icon(Icons.auto_awesome, color: Colors.white70, size: 12),
                      ),
                      Positioned(
                        bottom: 14,
                        left: 18,
                        child: Icon(Icons.auto_awesome, color: Colors.white54, size: 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showParticles)
              ..._particles.map((particle) {
                return Positioned(
                  top: -30,
                  left: particle.left * MediaQuery.of(context).size.width * 0.75,
                  child: AnimatedBuilder(
                    animation: _confettiController,
                    builder: (context, child) {
                      final progress = _confettiController.value;
                      final particleProgress =
                          (progress - particle.delay.inMilliseconds / 2500).clamp(0.0, 1.0);

                      if (particleProgress <= 0) return const SizedBox.shrink();

                      return Transform.rotate(
                        angle: particle.rotation + (particleProgress * 8 * particle.speed),
                        child: Opacity(
                          opacity: (1 - particleProgress * 0.7).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(
                              sin(particleProgress * 3) * 20,
                              particleProgress * 300 * particle.speed,
                            ),
                            child: Container(
                              width: particle.size,
                              height: particle.size * 1.5,
                              decoration: BoxDecoration(
                                color: particle.color.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(
                                  particle.size > 6 ? 3 : 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== MAIN PAGE ====================
class AjukanLemburPage extends StatefulWidget {
  const AjukanLemburPage({super.key});

  @override
  State<AjukanLemburPage> createState() => _AjukanLemburPageState();
}

class _AjukanLemburPageState extends State<AjukanLemburPage>
    with SingleTickerProviderStateMixin {
  // ==================== SERVICES ====================
  final OvertimeService _overtimeService = OvertimeService();
  final MitraLimitService _mitraLimitService = MitraLimitService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== ANIMATION ====================
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ==================== DATA STATE ====================
  bool isLoading = true;
  bool isCheckingDuplicates = false;
  Map<String, dynamic>? _overtimeRates;
  List<Map<String, dynamic>> selectedMiras = [];
  List<String> selectedMitraIds = [];
  Map<String, bool> mitraDuplicateStatus = {};
  Map<String, String> mitraDuplicateIds = {};

  // ==================== FORM DATA ====================
  DateTime? tanggalMulai;
  DateTime? tanggalSelesai;
  TimeOfDay? jamMulai;
  TimeOfDay? jamSelesai;
  double totalJam = 0.0;
  bool isMultiDay = false;
  bool isOvernight = false;
  String urgensi = 'normal';
  String? fungsiPengawas;
  String? namaPengawas;
  String? photoProfileUrl;

  // ==================== BUDGET DATA ====================
  double biayaLemburPerMitra = 0.0;
  double totalBiayaLembur = 0.0;
  bool showBudgetBreakdown = false;

  // ==================== LOCATION DATA ====================
  String _locationType = 'kantor';
  LatLng? _selectedLocation;
  String? _selectedAddress;
  final _rtController = TextEditingController();
  final _rwController = TextEditingController();

  // ==================== CONTROLLERS ====================
  final alasanController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // ==================== COMPUTED PROPERTIES ====================
  bool get _isOutsideRadius {
    if (_selectedLocation == null) return false;
    return LocationService.isOutsideRadius(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );
  }

  bool get _hasDuplicateMitra =>
      mitraDuplicateStatus.values.any((isDuplicate) => isDuplicate);

  List<Map<String, dynamic>> get _validMiras =>
      selectedMiras.where((m) => mitraDuplicateStatus[m['id']] != true).toList();

  List<Map<String, dynamic>> get _duplicateMiras =>
      selectedMiras.where((m) => mitraDuplicateStatus[m['id']] == true).toList();

  bool _allDataComplete() {
    return selectedMiras.isNotEmpty &&
        _validMiras.isNotEmpty &&
        tanggalMulai != null &&
        tanggalSelesai != null &&
        jamMulai != null &&
        jamSelesai != null &&
        _selectedLocation != null &&
        alasanController.text.isNotEmpty &&
        alasanController.text.length >= 20 &&
        urgensi.isNotEmpty &&
        !_hasDuplicateMitra;
  }

  double get _completionPercentage {
    int completed = 0;
    const total = 8;
    if (selectedMiras.isNotEmpty && _validMiras.isNotEmpty) completed++;
    if (tanggalMulai != null) completed++;
    if (tanggalSelesai != null) completed++;
    if (jamMulai != null && jamSelesai != null) completed++;
    if (_selectedLocation != null) completed++;
    if (alasanController.text.length >= 20) completed++;
    if (urgensi.isNotEmpty) completed++;
    return completed / total;
  }

  // ==================== HELPER FUNCTIONS ====================
  List<DateTime> _getDatesInRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    for (var d = startDay; !d.isAfter(endDay); d = d.add(const Duration(days: 1))) {
      dates.add(d);
    }
    return dates;
  }

  bool _isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    alasanController.dispose();
    _rtController.dispose();
    _rwController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([_loadUserData(), _loadOvertimeRates()]);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists && mounted) {
      final data = userDoc.data();
      setState(() {
        fungsiPengawas = data?['fungsi']?.toString().toLowerCase() ?? '';
        namaPengawas = data?['nama_lengkap'] ?? 'Pengawas';
        photoProfileUrl = data?['photo_url'];
      });
    }
  }

  Future<void> _loadOvertimeRates() async {
    _overtimeRates = await _overtimeService.loadOvertimeRates();
    if (mounted) setState(() {});
  }

  // ==================== DUPLICATE CHECK ====================
  Future<void> _checkDuplicateLembur() async {
    if (tanggalMulai == null || tanggalSelesai == null || selectedMiras.isEmpty) return;
    setState(() => isCheckingDuplicates = true);

    for (final mitra in selectedMiras) {
      final result = await _mitraLimitService.checkDuplicateLemburRentang(
        mitraId: mitra['id'],
        tanggalMulai: tanggalMulai!,
        tanggalSelesai: tanggalSelesai!,
      );

      if (mounted) {
        setState(() {
          mitraDuplicateStatus[mitra['id']] = result['is_duplicate'] ?? false;
          if (result['is_duplicate'] == true && result['existing_ids'] != null) {
            final ids = result['existing_ids'] as List;
            mitraDuplicateIds[mitra['id']] = ids.isNotEmpty ? ids.first.toString() : '';
          }
        });
      }
    }
    if (mounted) setState(() => isCheckingDuplicates = false);
  }

  // ==================== CALCULATION ====================
  void _recalculateBiaya() {
    if (jamMulai == null || jamSelesai == null ||
        tanggalMulai == null || tanggalSelesai == null ||
        _overtimeRates == null) return;

    final startDateTime = DateTime(
      tanggalMulai!.year, tanggalMulai!.month, tanggalMulai!.day,
      jamMulai!.hour, jamMulai!.minute,
    );
    final endDateTime = DateTime(
      tanggalSelesai!.year, tanggalSelesai!.month, tanggalSelesai!.day,
      jamSelesai!.hour, jamSelesai!.minute,
    );

    final diffInMinutes = endDateTime.difference(startDateTime).inMinutes;

    if (diffInMinutes <= 0) {
      if (mounted) {
        setState(() {
          totalJam = 0;
          showBudgetBreakdown = false;
        });
      }
      return;
    }

    totalJam = diffInMinutes / 60.0;

    isMultiDay = tanggalMulai!.year != tanggalSelesai!.year ||
                 tanggalMulai!.month != tanggalSelesai!.month ||
                 tanggalMulai!.day != tanggalSelesai!.day;
    isOvernight = !isMultiDay && (jamSelesai!.hour < jamMulai!.hour ||
                   (jamSelesai!.hour == jamMulai!.hour && jamSelesai!.minute <= jamMulai!.minute));

    biayaLemburPerMitra = _calculateMultiDayCost(
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      rates: _overtimeRates!,
    );

    totalBiayaLembur = biayaLemburPerMitra * _validMiras.length;

    setState(() => showBudgetBreakdown = true);
    _checkDuplicateLembur();
  }

  double _calculateMultiDayCost({
    required DateTime startDateTime,
    required DateTime endDateTime,
    required Map<String, dynamic> rates,
  }) {
    double totalCost = 0;
    DateTime currentDay = DateTime(
      startDateTime.year, startDateTime.month, startDateTime.day,
    );

    while (!currentDay.isAfter(DateTime(endDateTime.year, endDateTime.month, endDateTime.day))) {
      final dayStart = DateTime(currentDay.year, currentDay.month, currentDay.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final effectiveStart = startDateTime.isAfter(dayStart) ? startDateTime : dayStart;
      final effectiveEnd = endDateTime.isBefore(dayEnd) ? endDateTime : dayEnd;

      if (effectiveStart.isBefore(effectiveEnd)) {
        final hoursToday = effectiveEnd.difference(effectiveStart).inMinutes / 60.0;
        final isHoliday = _isWeekend(currentDay);

        totalCost += _overtimeService.calculateOvertimeCost(
          totalHours: hoursToday,
          isHoliday: isHoliday,
          rates: rates,
        );
      }

      currentDay = currentDay.add(const Duration(days: 1));
    }

    return totalCost;
  }

  // ==================== FORMAT HELPERS ====================
  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatTanggal(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ==================== MAP PICKER ====================
  void _showMapPicker() async {
    final initialLat = _selectedLocation?.latitude ?? LocationService.kantorLat;
    final initialLng = _selectedLocation?.longitude ?? LocationService.kantorLng;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initialLat: initialLat,
          initialLng: initialLng,
          isProjectLocation: _locationType == 'proyek',
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocation = LatLng(
          (result['lat'] as num).toDouble(),
          (result['lng'] as num).toDouble(),
        );
        _selectedAddress = result['address'] ?? 'Lokasi dipilih dari peta';
      });
    }
  }

  // ==================== MITRA SELECTION ====================
  Future<void> _showMitraSelectionDialog() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => MitraSelectionDialog(
        fungsi: fungsiPengawas!,
        selectedIds: selectedMitraIds,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        selectedMiras = result;
        selectedMitraIds = result.map((m) => m['id'] as String).toList();
      });
      if (tanggalMulai != null && tanggalSelesai != null) _checkDuplicateLembur();
      _recalculateBiaya();
    }
  }

  // ==================== VALIDASI TERPUSAT ====================
  String? _validateAllData() {
    if (selectedMiras.isEmpty) {
      return 'Pilih minimal satu TAD';
    }
    if (_validMiras.isEmpty) {
      return 'Hapus TAD yang sudah terdaftar lembur di rentang tanggal ini';
    }

    if (tanggalMulai == null) {
      return 'Tanggal mulai lembur harus diisi';
    }
    if (tanggalSelesai == null) {
      return 'Tanggal selesai lembur harus diisi';
    }
    if (tanggalSelesai!.isBefore(tanggalMulai!)) {
      return 'Tanggal selesai harus ≥ tanggal mulai';
    }
    if (jamMulai == null || jamSelesai == null) {
      return 'Waktu lembur tidak valid';
    }
    if (totalJam <= 0) {
      return 'Durasi lembur harus > 0';
    }

    if (_locationType == 'proyek' && _selectedLocation == null) {
      return 'Lokasi proyek tidak ditemukan. Silakan pilih lokasi';
    }
    if (_selectedLocation == null) {
      return 'Pilih lokasi lembur';
    }

    if (alasanController.text.isEmpty) {
      return 'Alasan lembur harus diisi';
    }
    if (alasanController.text.length < 20) {
      return 'Alasan lembur minimal 20 karakter';
    }

    if (urgensi.isEmpty) {
      return 'Tingkat urgensi harus dipilih';
    }

    return null;
  }

  // ==================== SUBMIT ====================
  Future<void> _submit() async {
    final validationError = _validateAllData();

    if (validationError != null) {
      if (mounted) {
        _showValidationError(validationError);
      }
      return;
    }

    final groupId = DateTime.now().millisecondsSinceEpoch.toString();

    bool hasLimitExceeded = false;
    final limitResults = <String, dynamic>{};

    for (final mitra in _validMiras) {
      final result = await _mitraLimitService.checkMitraLimit(
        mitraId: mitra['id'],
        tanggal: tanggalMulai!,
        tambahanJam: totalJam,
      );
      limitResults[mitra['id']] = result;
      if (result['is_exceeded']) hasLimitExceeded = true;
    }

    if (hasLimitExceeded) {
      final confirmed = await _showLimitWarningDialog(limitResults);
      if (!confirmed) {
        return;
      }
    }

    _showLoadingDialog();

    try {
      await _saveOvertimeData(hasLimitExceeded, groupId);

      if (mounted) {
        try {
          await NotificationService().sendManagerNotification(
            pengawasNama: namaPengawas ?? 'Pengawas',
            fungsi: fungsiPengawas ?? '',
            jumlahMitra: _validMiras.length,
            tanggal: tanggalMulai!,
            totalBiaya: totalBiayaLembur,
            urgensi: urgensi,
            isOutsideRadius: _isOutsideRadius,
            lemburIds: [groupId],
            overtimeRates: _overtimeRates!,
          );

          // 🔔 Kabari Superadmin juga ada pengajuan lembur baru masuk
          NotificationService().notifySuperAdmins(
            type: 'lembur_submitted',
            title: '📋 Pengajuan Lembur Baru',
            message: '${namaPengawas ?? "Pengawas"} mengajukan lembur untuk ${_validMiras.length} mitra'
                ' (${fungsiPengawas ?? "-"}).',
            data: {
              'groupId': groupId,
              'pengawasNama': namaPengawas ?? '',
              'fungsi': fungsiPengawas ?? '',
              'jumlahMitra': _validMiras.length,
            },
            priority: 3,
          );
        } catch (e) {
          debugPrint('⚠️ Gagal kirim notifikasi: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog(groupId);
      }
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      if (mounted) {
        Navigator.pop(context);
        _showValidationError('Gagal menyimpan: $e');
      }
    }
  }

  // ==================== SAVE DATA ====================
  Future<void> _saveOvertimeData(bool hasLimitExceeded, String groupId) async {
    final batch = _firestore.batch();
    final now = Timestamp.now();
    final isOutside = _isOutsideRadius;

    String alamatLengkap = _selectedAddress ?? '';
    if (_locationType == 'proyek') {
      if (_rtController.text.trim().isNotEmpty) {
        alamatLengkap += ' RT ${_rtController.text.trim()}';
      }
      if (_rwController.text.trim().isNotEmpty) {
        alamatLengkap += ' RW ${_rwController.text.trim()}';
      }
    }

    // 🔥 PERSIAPKAN DATA MITRA UNTUK BERBAGAI FORMAT
    final mitraListData = _validMiras
        .map((m) => {
              'id': m['id'],
              'nama_mitra': m['nama_lengkap'],
              'fungsi_mitra': m['fungsi'],
            })
        .toList();

    final detailMitraData = _validMiras
        .map((m) => {
              'id': m['id'],
              'nama': m['nama_lengkap'],
              'fungsi': m['fungsi'],
            })
        .toList();

    final pengajuanRef = _firestore.collection('pengajuan_lembur').doc(groupId);
    batch.set(pengajuanRef, {
      'group_id': groupId,
      'tipe_dokumen': 'pengajuan',
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
      'pengawas_id': _auth.currentUser?.uid,
      'nama_pengawas': namaPengawas,
      'pengawas_fungsi': fungsiPengawas,
      'tanggal_mulai': Timestamp.fromDate(tanggalMulai!),
      'tanggal_selesai': Timestamp.fromDate(tanggalSelesai!),
      'is_multi_day': isMultiDay,
      'is_overnight': isOvernight,
      'tanggal_lembur': Timestamp.fromDate(tanggalMulai!),
      'tahun_bulan': DateFormat('yyyy-MM').format(tanggalMulai!),
      'jam_mulai': _formatTime(jamMulai!),
      'jam_selesai': _formatTime(jamSelesai!),
      'total_jam_desimal': totalJam,
      'jenis_lembur': _isWeekend(tanggalMulai!) ? 'hari_libur' : 'hari_kerja',
      'lokasi': {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'alamat': alamatLengkap,
        'rt': _locationType == 'proyek' ? _rtController.text.trim() : '',
        'rw': _locationType == 'proyek' ? _rwController.text.trim() : '',
        'is_outside_radius': isOutside,
        'tipe_lokasi': _locationType,
      },
      'estimasi_biaya_total': totalBiayaLembur,
      'estimasi_biaya_per_mitra': biayaLemburPerMitra,
      'rate_snapshot': _overtimeRates,
      'total_mitra': _validMiras.length,
      'mitra_ids': _validMiras.map((m) => m['id'] as String).toList(),
      // 🔥 FIELD BARU: mitra_list (dibaca oleh SpklGeneratorService)
      'mitra_list': mitraListData,
      // Field existing: detail_mitra (backward compatible)
      'detail_mitra': detailMitraData,
      'urgensi': urgensi,
      'alasan': alasanController.text.trim(),
      'is_override': hasLimitExceeded,
      'is_multiple': _validMiras.length > 1,
      'location_type': _locationType,
    });

    final allDates = _getDatesInRange(tanggalMulai!, tanggalSelesai!);

    final baseMitraData = {
      'group_id': groupId,
      'pengajuan_id': groupId,
      'tipe_dokumen': 'lembur_mitra',
      'pengawas_id': _auth.currentUser?.uid,
      'pengawas_fungsi': fungsiPengawas,
      'diajukan_oleh_id': _auth.currentUser?.uid,
      'diajukan_oleh_nama': namaPengawas,
      'lokasi': {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'alamat': alamatLengkap,
        'rt': _locationType == 'proyek' ? _rtController.text.trim() : '',
        'rw': _locationType == 'proyek' ? _rwController.text.trim() : '',
        'is_outside_radius': isOutside,
        'tipe_lokasi': _locationType,
      },
      'estimasi_biaya_per_mitra': biayaLemburPerMitra,
      'estimasi_biaya': biayaLemburPerMitra,
      'rate_snapshot': _overtimeRates,
      'status': 'pending',
      'absensi_status': 'belum_absen',
      'urgensi': urgensi,
      'alasan': alasanController.text.trim(),
      'is_override': hasLimitExceeded,
      'created_at': now,
      'updated_at': now,
    };

    for (final mitra in _validMiras) {
      for (final date in allDates) {
        final isHoliday = _isWeekend(date);

        TimeOfDay dayStart = const TimeOfDay(hour: 0, minute: 0);
        TimeOfDay dayEnd = const TimeOfDay(hour: 23, minute: 59);

        if (date.year == tanggalMulai!.year &&
            date.month == tanggalMulai!.month &&
            date.day == tanggalMulai!.day) {
          dayStart = jamMulai!;
        }
        if (date.year == tanggalSelesai!.year &&
            date.month == tanggalSelesai!.month &&
            date.day == tanggalSelesai!.day) {
          dayEnd = jamSelesai!;
        }

        final docId = '${groupId}_${mitra['id']}_${DateFormat('yyyyMMdd').format(date)}';
        final docRef = _firestore.collection('lembur_mitra').doc(docId);

        batch.set(docRef, {
          ...baseMitraData,
          'mitra_id': mitra['id'],
          'user_id': mitra['id'],
          'nama_mitra': mitra['nama_lengkap'],
          'fungsi_mitra': mitra['fungsi'],
          'tanggal': Timestamp.fromDate(date),
          'tahun_bulan': DateFormat('yyyy-MM').format(date),
          'jam_mulai': _formatTime(dayStart),
          'jam_selesai': _formatTime(dayEnd),
          'total_jam_desimal': totalJam,
          'jenis_lembur': isHoliday ? 'hari_libur' : 'hari_kerja',
        });
      }
    }

    await batch.commit();
    debugPrint('✅ Data tersimpan untuk group: $groupId (${allDates.length} hari, ${_validMiras.length} mitra)');
    debugPrint('✅ mitra_list tersimpan: ${mitraListData.length} mitra');
  }

  // ==================== DIALOGS ====================
  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1976D2)),
                SizedBox(height: 24),
                Text('Menyimpan Pengajuan...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('Mohon tunggu sebentar',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showLimitWarningDialog(Map<String, dynamic> limitResults) async {
    final mitraOver = <String>[];
    limitResults.forEach((mitraId, info) {
      if (info['is_exceeded']) {
        final mitra = _validMiras.firstWhere((m) => m['id'] == mitraId);
        mitraOver.add(
          '• ${mitra['nama_lengkap']}: ${info['total_jam_bulan_ini'].toStringAsFixed(1)} jam + ${info['tambahan_jam'].toStringAsFixed(1)} jam',
        );
      }
    });

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Melebihi Batas Lembur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Beberapa TAD akan melebihi batas maksimal 60 jam/bulan:'),
            const SizedBox(height: 12),
            ...mitraOver.map((m) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Text(m, style: const TextStyle(fontSize: 13)),
                )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pengajuan ini akan ditandai sebagai OVERRIDE dan memerlukan persetujuan khusus.',
                style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('TETAP AJUKAN',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog(String groupId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return _SuccessDialogContent(
          groupId: groupId,
          validMirasCount: _validMiras.length,
          isMultiDay: isMultiDay,
          isOvernight: isOvernight,
          namaPengawas: namaPengawas,
          fungsiPengawas: fungsiPengawas,
          formatRupiah: (double value) => _overtimeService.formatRupiah(value),
          totalBiayaLembur: totalBiayaLembur,
          onSelesai: () {
            Navigator.pop(context);
            if (mounted) context.pop();
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.elasticOut,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) => PreviewDialog(
        namaPengawas: namaPengawas,
        fungsiPengawas: fungsiPengawas,
        validMiras: _validMiras,
        tanggalLembur: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
        totalJam: totalJam,
        isMultiDay: isMultiDay,
        isOvernight: isOvernight,
        locationType: _locationType,
        selectedAddress: _selectedAddress,
        rtController: _rtController,
        rwController: _rwController,
        urgensi: urgensi,
        biayaLemburPerMitra: biayaLemburPerMitra,
        totalBiayaLembur: totalBiayaLembur,
        alasan: alasanController.text,
        formatTime: _formatTime,
        formatTanggal: _formatTanggal,
        formatRupiah: (double value) => _overtimeService.formatRupiah(value),
        onConfirmed: () {
          Navigator.pop(context);
          _submit();
        },
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF1976D2),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Memuat data...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mohon tunggu sebentar',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final bottomNavHeight = 65.0;
    final extraPadding = bottomPadding + bottomNavHeight;

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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_alarm_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Pengajuan Lembur',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_rounded,
                size: 18, color: Colors.white),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: Colors.white),
            ),
            onPressed: () async {
              _overtimeService.clearCache();
              await _loadOvertimeRates();
            },
          ),
          if (_completionPercentage > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                constraints: const BoxConstraints(maxWidth: 45),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${(_completionPercentage * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(16, 16, 16, extraPadding + 8),
              child: Column(
                children: [
                  HeaderProfileCard(
                    namaPengawas: namaPengawas,
                    fungsiPengawas: fungsiPengawas,
                    photoProfileUrl: photoProfileUrl,
                  ),
                  const SizedBox(height: 16),
                  ProgressStepper(
                    completionPercentage: _completionPercentage,
                    hasMitra: _validMiras.isNotEmpty,
                    hasTanggal: tanggalMulai != null && tanggalSelesai != null,
                    hasWaktu: jamMulai != null && jamSelesai != null,
                    hasLokasi: _selectedLocation != null,
                    hasAlasan: alasanController.text.length >= 20,
                    isMultiDay: isMultiDay,
                    isOvernight: isOvernight,
                  ),
                  const SizedBox(height: 16),
                  if (_overtimeRates != null)
                    RateInfoCard(rates: _overtimeRates!),
                  const SizedBox(height: 16),
                  MitraSection(
                    selectedMiras: selectedMiras,
                    validMiras: _validMiras,
                    duplicateMiras: _duplicateMiras,
                    mitraDuplicateStatus: mitraDuplicateStatus,
                    hasDuplicateMitra: _hasDuplicateMitra,
                    isCheckingDuplicates: isCheckingDuplicates,
                    fungsiPengawas: fungsiPengawas,
                    tanggalLembur: tanggalMulai,
                    onAddMitra: _showMitraSelectionDialog,
                    onRemoveMitra: (mitra) {
                      setState(() {
                        selectedMiras.removeWhere((m) => m['id'] == mitra['id']);
                        selectedMitraIds.remove(mitra['id']);
                        mitraDuplicateStatus.remove(mitra['id']);
                      });
                      _recalculateBiaya();
                    },
                    formatTanggal: _formatTanggal,
                  ),
                  const SizedBox(height: 16),
                  WaktuSection(
                    tanggalMulai: tanggalMulai,
                    tanggalSelesai: tanggalSelesai,
                    jamMulai: jamMulai,
                    jamSelesai: jamSelesai,
                    totalJam: totalJam,
                    isMultiDay: isMultiDay,
                    isOvernight: isOvernight,
                    onTanggalMulaiChanged: (date) {
                      setState(() {
                        tanggalMulai = date;
                        if (tanggalSelesai == null || (date != null && tanggalSelesai!.isBefore(date))) {
                          tanggalSelesai = date;
                        }
                        jamMulai = null;
                        jamSelesai = null;
                        totalJam = 0;
                        isMultiDay = false;
                        isOvernight = false;
                      });
                    },
                    onTanggalSelesaiChanged: (date) {
                      setState(() {
                        tanggalSelesai = date;
                        jamSelesai = null;
                        totalJam = 0;
                        isMultiDay = false;
                        isOvernight = false;
                      });
                    },
                    onJamMulaiChanged: (time) {
                      setState(() {
                        jamMulai = time;
                        jamSelesai = null;
                        totalJam = 0;
                        isOvernight = false;
                      });
                    },
                    onJamSelesaiChanged: (time) {
                      jamSelesai = time;
                      _recalculateBiaya();
                    },
                    onClear: () {
                      setState(() {
                        tanggalMulai = null;
                        tanggalSelesai = null;
                        jamMulai = null;
                        jamSelesai = null;
                        totalJam = 0;
                        isMultiDay = false;
                        isOvernight = false;
                        showBudgetBreakdown = false;
                      });
                    },
                    formatTime: _formatTime,
                    formatTanggal: _formatTanggal,
                  ),
                  const SizedBox(height: 16),
                  LokasiSection(
                    locationType: _locationType,
                    selectedLocation: _selectedLocation,
                    selectedAddress: _selectedAddress,
                    isOutsideRadius: _isOutsideRadius,
                    rtController: _rtController,
                    rwController: _rwController,
                    onLocationTypeChanged: (type) {
                      setState(() {
                        _locationType = type;
                        if (type == 'kantor') {
                          _selectedLocation = LatLng(
                            LocationService.kantorLat,
                            LocationService.kantorLng,
                          );
                          _selectedAddress = LocationService.alamatKantor;
                          _rtController.clear();
                          _rwController.clear();
                        } else {
                          _selectedLocation = null;
                          _selectedAddress = null;
                        }
                      });
                    },
                    onPickMap: _showMapPicker,
                  ),
                  const SizedBox(height: 16),
                  AlasanSection(
                    controller: alasanController,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  UrgensiSection(
                    urgensi: urgensi,
                    onUrgensiChanged: (value) {
                      setState(() {
                        urgensi = value;
                        if (value == 'normal') {
                          _locationType = 'kantor';
                          _selectedLocation = LatLng(
                            LocationService.kantorLat,
                            LocationService.kantorLng,
                          );
                          _selectedAddress = LocationService.alamatKantor;
                          _rtController.clear();
                          _rwController.clear();
                        } else {
                          _locationType = 'proyek';
                        }
                      });
                    },
                  ),
                  if (showBudgetBreakdown && totalJam > 0 && _validMiras.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    BudgetBreakdownSection(
                      totalJam: totalJam,
                      validMirasCount: _validMiras.length,
                      biayaLemburPerMitra: biayaLemburPerMitra,
                      totalBiayaLembur: totalBiayaLembur,
                      formatRupiah: (double value) => _overtimeService.formatRupiah(value),
                      isMultiDay: isMultiDay,
                      isOvernight: isOvernight,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SubmitButton(
                    isComplete: _allDataComplete(),
                    hasDuplicateMitra: _hasDuplicateMitra,
                    completionPercentage: _completionPercentage,
                    onPressed: () => _showPreviewDialog(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: PengawasBottomNav(
        currentIndex: 1,
      ),
    );
  }
}