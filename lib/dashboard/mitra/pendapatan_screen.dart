// lib/screens/pendapatan_screen.dart
// 🔥 VERSION 3.0 - FIXED INFINITE LOOP & FLICKERING
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/core/services/pendapatan_service.dart';
import '/widgets/pendapatan/pendapatan_header_card.dart';
import '/widgets/pendapatan/pendapatan_list_item.dart';
import '/widgets/pendapatan/pendapatan_detail_sheet.dart';
import '/widgets/bottom_nav/mitra_bottom_nav.dart';

// ============================================================
// 📊 RINGKASAN DATA CLASS
// ============================================================
class PendapatanRingkasan {
  final double totalPendapatan;
  final int totalLembur;
  final double totalJam;
  final int tepatWaktu;
  final int terlambat;
  final int sudahDibayar;
  final int belumDibayar;
  final double totalDibayar;
  final double totalBelumDibayar;

  const PendapatanRingkasan({
    this.totalPendapatan = 0,
    this.totalLembur = 0,
    this.totalJam = 0,
    this.tepatWaktu = 0,
    this.terlambat = 0,
    this.sudahDibayar = 0,
    this.belumDibayar = 0,
    this.totalDibayar = 0,
    this.totalBelumDibayar = 0,
  });

  factory PendapatanRingkasan.fromItems(List<PendapatanItem> items) {
    double total = 0;
    double totalJam = 0;
    int tepat = 0;
    int lambat = 0;
    int sudah = 0;
    int belum = 0;
    double dibayar = 0;
    double blm = 0;

    for (var item in items) {
      total += item.estimasiPendapatan;
      totalJam += item.totalJam;
      if (item.statusAbsensi == 'selesai') {
        tepat++;
      } else if (item.statusAbsensi == 'selesai_terlambat') {
        lambat++;
      }
      if (item.isPaid) {
        sudah++;
        dibayar += item.estimasiPendapatan;
      } else {
        belum++;
        blm += item.estimasiPendapatan;
      }
    }

    return PendapatanRingkasan(
      totalPendapatan: total,
      totalLembur: items.length,
      totalJam: totalJam,
      tepatWaktu: tepat,
      terlambat: lambat,
      sudahDibayar: sudah,
      belumDibayar: belum,
      totalDibayar: dibayar,
      totalBelumDibayar: blm,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PendapatanRingkasan &&
        other.totalPendapatan == totalPendapatan &&
        other.totalLembur == totalLembur &&
        other.totalJam == totalJam &&
        other.tepatWaktu == tepatWaktu &&
        other.terlambat == terlambat &&
        other.sudahDibayar == sudahDibayar &&
        other.belumDibayar == belumDibayar &&
        other.totalDibayar == totalDibayar &&
        other.totalBelumDibayar == totalBelumDibayar;
  }

  @override
  int get hashCode => Object.hash(
    totalPendapatan, totalLembur, totalJam,
    tepatWaktu, terlambat, sudahDibayar, belumDibayar,
    totalDibayar, totalBelumDibayar,
  );
}

// ============================================================
// 📱 MAIN SCREEN
// ============================================================
class PendapatanScreen extends StatefulWidget {
  const PendapatanScreen({super.key});

  @override
  State<PendapatanScreen> createState() => _PendapatanScreenState();
}

class _PendapatanScreenState extends State<PendapatanScreen>
    with WidgetsBindingObserver {
  final PendapatanService _pendapatanService = PendapatanService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State
  String? _userId;
  String _userName = 'Mitra';
  String _selectedBulan = DateFormat('yyyy-MM').format(DateTime.now());
  bool _isInitialLoad = true;
  String? _errorMessage;

  // 🔥 RINGKASAN - dengan ValueNotifier untuk menghindari rebuild
  final ValueNotifier<PendapatanRingkasan> _ringkasanNotifier = 
      ValueNotifier(const PendapatanRingkasan());

  // 🔥 Stream subscription untuk kontrol
  StreamSubscription<List<PendapatanItem>>? _subscription;
  
  // 🔥 Flag untuk mencegah reload berlebihan
  bool _isRefreshing = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _ringkasanNotifier.dispose();
    _pendapatanService.clearCache();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 🔥 FIX: Hanya refresh jika benar-benar diperlukan dan tidak sedang loading
    if (state == AppLifecycleState.resumed && 
        _userId != null && 
        !_isRefreshing && 
        !_isDisposed) {
      _refreshDataSilent();
    }
  }

  // ============================================================
  // LOAD USER DATA
  // ============================================================
  Future<void> _loadUserData() async {
    if (_isDisposed) return;
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted && !_isDisposed) {
          setState(() {
            _errorMessage = 'User tidak terautentikasi. Silakan login ulang.';
            _isInitialLoad = false;
          });
        }
        return;
      }

      String? namaLengkap;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        namaLengkap = userDoc.data()?['nama_lengkap'] as String?;
      } catch (e) {
        debugPrint('⚠️ Gagal load user data dari Firestore: $e');
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _userId = user.uid;
          _userName = namaLengkap ?? user.displayName ?? 'Mitra';
          _isInitialLoad = false;
        });
        // Mulai stream setelah user ID didapat
        _startStream();
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _errorMessage = 'Gagal memuat data pengguna: $e';
          _isInitialLoad = false;
        });
      }
    }
  }

  // ============================================================
  // 🔥 STREAM MANAGEMENT
  // ============================================================
  void _startStream() {
    if (_userId == null || _isDisposed) return;
    
    _subscription?.cancel();
    _subscription = _pendapatanService
        .getPendapatanStream(
          mitraId: _userId!,
          bulan: _selectedBulan,
        )
        .listen((items) {
          if (_isDisposed || !mounted) return;
          
          // 🔥 Update ringkasan
          final ringkasanBaru = PendapatanRingkasan.fromItems(items);
          if (_ringkasanNotifier.value != ringkasanBaru) {
            _ringkasanNotifier.value = ringkasanBaru;
          }
          
          // Update UI hanya jika data berubah
          setState(() {});
        }, onError: (e) {
          if (_isDisposed || !mounted) return;
          debugPrint('❌ Stream error: $e');
          setState(() {
            _errorMessage = 'Gagal memuat data: $e';
          });
        });
  }

  // 🔥 Silent refresh - tanpa mengubah key
  Future<void> _refreshDataSilent() async {
    if (_isRefreshing || _isDisposed) return;
    _isRefreshing = true;
    
    _pendapatanService.clearCache();
    _startStream(); // Restart stream
    
    await Future.delayed(const Duration(milliseconds: 100));
    _isRefreshing = false;
  }

  // 🔥 Refresh dengan indicator
  Future<void> _refreshData() async {
    if (_isRefreshing || _isDisposed) return;
    _isRefreshing = true;
    
    _pendapatanService.clearCache();
    _startStream();
    
    await Future.delayed(const Duration(milliseconds: 200));
    _isRefreshing = false;
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    // Error State
    if (_errorMessage != null && _userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(
            'Pendapatan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        body: _buildErrorScreen(
          icon: Icons.person_off_rounded,
          title: 'Tidak Dapat Memuat',
          message: _errorMessage!,
          onRetry: () {
            setState(() {
              _errorMessage = null;
              _isInitialLoad = true;
            });
            _loadUserData();
          },
        ),
      );
    }

    // Initial Loading
    if (_isInitialLoad || _userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLoadingIndicator(),
              const SizedBox(height: 20),
              Text(
                _isInitialLoad ? 'Memuat data pengguna...' : 'Mohon tunggu...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildContent()),
            const MitraBottomNav(currentIndex: 2),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  PreferredSizeWidget _buildAppBar() {
    final displayBulan = _formatBulanDisplay(_selectedBulan);

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pendapatan',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: _showMonthPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayBulan,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1B5E20),
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 22),
          onPressed: _refreshData,
          tooltip: 'Refresh Data',
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            onPressed: _showMonthPicker,
            tooltip: 'Pilih Bulan',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MAIN CONTENT - USING VALUE LISTENABLE BUILDER
  // ============================================================
  Widget _buildContent() {
    return StreamBuilder<List<PendapatanItem>>(
      stream: _pendapatanService.getPendapatanStream(
        mitraId: _userId!,
        bulan: _selectedBulan,
      ),
      builder: (context, snapshot) {
        // LOADING STATE
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingContent();
        }

        // ERROR STATE
        if (snapshot.hasError) {
          return _buildErrorScreen(
            icon: Icons.cloud_off_rounded,
            title: 'Gagal Memuat Data',
            message: 'Terjadi kesalahan saat mengambil data pendapatan.\n'
                'Periksa koneksi internet Anda dan coba lagi.',
            errorDetail: snapshot.error.toString(),
            onRetry: _refreshData,
          );
        }

        // DATA STATE
        final items = snapshot.data ?? [];
        
        // 🔥 Update ringkasan tanpa setState
        final ringkasanBaru = PendapatanRingkasan.fromItems(items);
        if (_ringkasanNotifier.value != ringkasanBaru) {
          _ringkasanNotifier.value = ringkasanBaru;
        }

        // EMPTY STATE
        if (items.isEmpty) {
          return _buildEmptyState();
        }

        // CONTENT WITH DATA
        return RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF1B5E20),
          displacement: 20,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Header Card - menggunakan ValueListenableBuilder
              SliverToBoxAdapter(
                child: ValueListenableBuilder<PendapatanRingkasan>(
                  valueListenable: _ringkasanNotifier,
                  builder: (context, ringkasan, _) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: PendapatanHeaderCard(
                        totalPendapatan: ringkasan.totalPendapatan,
                        totalLembur: ringkasan.totalLembur,
                        totalJam: ringkasan.totalJam,
                        bulan: _selectedBulan,
                        tepatWaktu: ringkasan.tepatWaktu,
                        terlambat: ringkasan.terlambat,
                      ),
                    );
                  },
                ),
              ),

              // Payment Status Card
              SliverToBoxAdapter(
                child: ValueListenableBuilder<PendapatanRingkasan>(
                  valueListenable: _ringkasanNotifier,
                  builder: (context, ringkasan, _) {
                    if (ringkasan.totalLembur > 0) {
                      return _buildPaymentStatusCard(ringkasan);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),

              // Disclaimer
              SliverToBoxAdapter(
                child: _buildDisclaimer(),
              ),

              // Section Header
              SliverToBoxAdapter(
                child: ValueListenableBuilder<PendapatanRingkasan>(
                  valueListenable: _ringkasanNotifier,
                  builder: (context, ringkasan, _) {
                    return _buildSectionHeader(
                      count: items.length,
                      totalPendapatan: ringkasan.totalPendapatan,
                    );
                  },
                ),
              ),

              // List Items
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    return _buildListItem(item, index);
                  },
                  childCount: items.length,
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: true,
                ),
              ),

              // Bottom Summary
              SliverToBoxAdapter(
                child: ValueListenableBuilder<PendapatanRingkasan>(
                  valueListenable: _ringkasanNotifier,
                  builder: (context, ringkasan, _) {
                    return _buildBottomSummary(ringkasan);
                  },
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // LIST ITEM
  // ============================================================
  Widget _buildListItem(PendapatanItem item, int index) {
    final shouldAnimate = index < 20;

    if (!shouldAnimate) {
      return PendapatanListItem(
        item: item,
        onTap: () => PendapatanDetailSheet.show(context, item),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(30 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: PendapatanListItem(
        item: item,
        onTap: () => PendapatanDetailSheet.show(context, item),
      ),
    );
  }

  // ============================================================
  // PAYMENT STATUS CARD
  // ============================================================
  Widget _buildPaymentStatusCard(PendapatanRingkasan ringkasan) {
    final persentase = ringkasan.totalLembur > 0
        ? (ringkasan.sudahDibayar / ringkasan.totalLembur * 100)
        : 0.0;
    final isComplete = persentase >= 100;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isComplete ? Icons.check_circle_rounded : Icons.payments_rounded,
                  size: 24,
                  color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Pembayaran',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isComplete
                          ? 'Semua gaji sudah dibayarkan 🎉'
                          : '${ringkasan.belumDibayar} laporan belum dibayar',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isComplete ? Colors.green.shade600 : Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isComplete ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  '${persentase.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: persentase / 100,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(
                isComplete ? Colors.green : Colors.orange,
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sudah Dibayar',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${ringkasan.sudahDibayar} laporan',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatRupiah(ringkasan.totalDibayar),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Belum Dibayar',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${ringkasan.belumDibayar} laporan',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatRupiah(ringkasan.totalBelumDibayar),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISCLAIMER
  // ============================================================
  Widget _buildDisclaimer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Estimasi Pendapatan',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pendapatan ini adalah ESTIMASI berdasarkan data lembur. '
                  'Status pembayaran diperbarui oleh admin secara berkala.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================
  Widget _buildSectionHeader({required int count, required double totalPendapatan}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Riwayat Lembur',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF1B5E20).withOpacity(0.15),
              ),
            ),
            child: Text(
              '$count item',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM SUMMARY
  // ============================================================
  Widget _buildBottomSummary(PendapatanRingkasan ringkasan) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_rounded, size: 18, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'Total Pendapatan',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Text(
                _formatRupiah(ringkasan.totalPendapatan),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Sudah Dibayar',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Text(
                _formatRupiah(ringkasan.totalDibayar),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pending_rounded, size: 16, color: Colors.orange.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Belum Dibayar',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Text(
                _formatRupiah(ringkasan.totalBelumDibayar),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem(
                icon: Icons.work_history_rounded,
                label: 'Total Lembur',
                value: '${ringkasan.totalLembur}x',
              ),
              _buildSummarySeparator(),
              _buildSummaryItem(
                icon: Icons.timer_rounded,
                label: 'Total Jam',
                value: _formatJam(ringkasan.totalJam),
              ),
              _buildSummarySeparator(),
              _buildSummaryItem(
                icon: Icons.check_circle_rounded,
                label: 'Tepat Waktu',
                value: '${ringkasan.tepatWaktu}',
              ),
              if (ringkasan.terlambat > 0) ...[
                _buildSummarySeparator(),
                _buildSummaryItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'Terlambat',
                  value: '${ringkasan.terlambat}',
                  isWarning: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    bool isWarning = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: isWarning
                ? Colors.orange.shade600
                : const Color(0xFF1B5E20).withOpacity(0.7),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isWarning ? Colors.orange.shade800 : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySeparator() {
    return Container(width: 1, height: 50, color: Colors.grey.shade200);
  }

  // ============================================================
  // LOADING CONTENT
  // ============================================================
  Widget _buildLoadingContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLoadingIndicator(),
          const SizedBox(height: 20),
          Text(
            'Memuat data pendapatan...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatBulanDisplay(_selectedBulan),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING INDICATOR
  // ============================================================
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const CircularProgressIndicator(
        color: Color(0xFF1B5E20),
        strokeWidth: 3,
      ),
    );
  }

  // ============================================================
  // ERROR SCREEN
  // ============================================================
  Widget _buildErrorScreen({
    required IconData icon,
    required String title,
    required String message,
    String? errorDetail,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade100.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, size: 72, color: Colors.red.shade300),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
            if (errorDetail != null && errorDetail.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  errorDetail.length > 150
                      ? '${errorDetail.substring(0, 150)}...'
                      : errorDetail,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.3,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================
  Widget _buildEmptyState() {
    final displayBulan = _formatBulanDisplay(_selectedBulan);
    final isCurrentMonth =
        _selectedBulan == DateFormat('yyyy-MM').format(DateTime.now());

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade100.withOpacity(0.6),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: Colors.green.shade400,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                isCurrentMonth ? 'Belum Ada Pendapatan' : 'Tidak Ada Data',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isCurrentMonth
                    ? 'Pendapatan akan muncul setelah Anda\n'
                        'menyelesaikan absensi lembur\n'
                        '(check-in & check-out).'
                    : 'Tidak ada data pendapatan untuk\n'
                        '$displayBulan.\n'
                        'Coba pilih bulan lain.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),
              if (isCurrentMonth) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber.shade100, Colors.amber.shade200],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lightbulb_rounded,
                              size: 22,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tips Mendapatkan Pendapatan',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildTipItem('1', 'Terima jadwal lembur dari pengawas',
                          Icons.assignment_turned_in_rounded),
                      _buildTipItem('2', 'Lakukan absensi check-in tepat waktu',
                          Icons.login_rounded),
                      _buildTipItem('3', 'Selesaikan lembur & lakukan check-out',
                          Icons.logout_rounded),
                      _buildTipItem('4', 'Pendapatan akan otomatis terhitung',
                          Icons.auto_graph_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              OutlinedButton.icon(
                onPressed: _showMonthPicker,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(
                  isCurrentMonth ? 'Lihat Bulan Lain' : 'Pilih Bulan',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B5E20),
                  side: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1B5E20).withOpacity(0.12),
                  const Color(0xFF2E7D32).withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: const Color(0xFF1B5E20).withOpacity(0.7)),
          ),
          const SizedBox(width: 12),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MONTH PICKER
  // ============================================================
  void _showMonthPicker() async {
    final currentDate = DateTime.parse('$_selectedBulan-01');

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        DateTime? selectedDate = currentDate;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        size: 22, color: Color(0xFF1B5E20)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pilih Bulan',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                height: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: selectedDate!.year > 2024
                                ? () => setDialogState(() {
                                      selectedDate = DateTime(
                                          selectedDate!.year - 1, selectedDate!.month);
                                    })
                                : null,
                          ),
                          Text(
                            '${selectedDate!.year}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: selectedDate!.year < 2030
                                ? () => setDialogState(() {
                                      selectedDate = DateTime(
                                          selectedDate!.year + 1, selectedDate!.month);
                                    })
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final date = DateTime(selectedDate!.year, month);
                          final isSelected = month == currentDate.month &&
                              selectedDate!.year == currentDate.year;
                          final isCurrentMonth = month == DateTime.now().month &&
                              selectedDate!.year == DateTime.now().year;
                          final isDisabled = date.isAfter(DateTime.now());

                          return GestureDetector(
                            onTap: isDisabled ? null : () => Navigator.pop(context, date),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1B5E20)
                                    : isCurrentMonth
                                        ? const Color(0xFF1B5E20).withOpacity(0.08)
                                        : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: isCurrentMonth
                                            ? const Color(0xFF1B5E20).withOpacity(0.25)
                                            : Colors.grey.shade300,
                                        width: isCurrentMonth ? 1.5 : 1,
                                      ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1B5E20).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  DateFormat('MMM', 'id_ID').format(date),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : isDisabled
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.poppins(
                        color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, DateTime.now()),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Bulan Ini',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted && !_isDisposed) {
      setState(() {
        _selectedBulan = DateFormat('yyyy-MM').format(result);
        _ringkasanNotifier.value = const PendapatanRingkasan();
      });
      _startStream(); // Restart stream with new month
    }
  }

  // ============================================================
  // FORMATTING HELPERS
  // ============================================================
  String _formatRupiah(double amount) {
    if (amount == 0) return 'Rp 0';
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatJam(double hours) {
    if (hours == 0) return '0 jam';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0 && m == 0) return '0 mnt';
    if (h == 0) return '$m mnt';
    if (m == 0) return '$h jam';
    return '$h jam $m mnt';
  }

  String _formatBulanDisplay(String tahunBulan) {
    try {
      final parts = tahunBulan.split('-');
      if (parts.length != 2) return tahunBulan;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      return DateFormat('MMMM yyyy', 'id_ID').format(DateTime(year, month));
    } catch (e) {
      return tahunBulan;
    }
  }
}