// lib/dashboard/superadmin/settings/overtime_rates_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../../core/services/overtime_rate_service.dart';
import '/widgets/bottom_nav/app_bottom_nav.dart';

var logger = Logger();

class OvertimeRatesScreen extends StatefulWidget {
  const OvertimeRatesScreen({super.key});

  @override
  State<OvertimeRatesScreen> createState() => _OvertimeRatesScreenState();
}

class _OvertimeRatesScreenState extends State<OvertimeRatesScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OvertimeRateService _rateService = OvertimeRateService();

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Data
  bool isLoading = true;
  bool isSaving = false;
  Map<String, dynamic> _rates = {};
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _gajiController = TextEditingController();
  
  // Tarif lembur
  double _upahPerJam = 0;
  double _firstHourMultiplier = 1.5;
  double _nextHoursMultiplier = 2.0;
  double _first8HoursMultiplier = 2.0;
  double _ninthHourMultiplier = 3.0;
  double _tenthPlusMultiplier = 4.0;
  
  // Riwayat
  List<Map<String, dynamic>> _rateHistory = [];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // Load rates dari service
      _rates = await _rateService.loadOvertimeRates(forceRefresh: true);
      
      // Parse data
      _upahPerJam = _rateService.getRatePerHour(_rates);
      final gaji = _rateService.getBaseSalary(_rates);
      _gajiController.text = NumberFormat('#,###').format(gaji);
      
      // Parse weekday rates
      final weekday = _rates['weekday_rate'] as Map<String, dynamic>?;
      if (weekday != null) {
        _firstHourMultiplier = (weekday['first_hour_multiplier'] as num?)?.toDouble() ?? 1.5;
        _nextHoursMultiplier = (weekday['next_hours_multiplier'] as num?)?.toDouble() ?? 2.0;
      }
      
      // Parse holiday rates
      final holiday = _rates['holiday_rate'] as Map<String, dynamic>?;
      if (holiday != null) {
        _first8HoursMultiplier = (holiday['first_8_hours_multiplier'] as num?)?.toDouble() ?? 2.0;
        _ninthHourMultiplier = (holiday['ninth_hour_multiplier'] as num?)?.toDouble() ?? 3.0;
        _tenthPlusMultiplier = (holiday['tenth_plus_multiplier'] as num?)?.toDouble() ?? 4.0;
      }
      
      // Load history
      await _loadHistory();

    } catch (e) {
      logger.e('Error loading data: $e');
      if (mounted) {
        _showSnackbar('Gagal memuat data tarif', isError: true);
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('overtime_rates')
          .collection('history')
          .orderBy('changed_at', descending: true)
          .limit(10)
          .get();

      _rateHistory = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'base_salary': (data['base_salary'] as num?)?.toDouble() ?? 0,
          'rate_per_hour': (data['rate_per_hour'] as num?)?.toDouble() ?? 0,
          'changed_by': data['changed_by'] as String? ?? 'system',
          'changed_at': (data['changed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      // Handle permission denied gracefully
      logger.w('Could not load history: $e');
      _rateHistory = [];
    }
  }

  Future<void> _saveRates() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final gajiString = _gajiController.text.replaceAll(RegExp(r'[^\d]'), '');
      final gaji = double.parse(gajiString);
      
      _upahPerJam = gaji / 173;

      final ratesData = {
        'base_salary': gaji,
        'rate_per_hour': _upahPerJam,
        'weekday_rate': {
          'first_hour_multiplier': _firstHourMultiplier,
          'next_hours_multiplier': _nextHoursMultiplier,
          'is_active': true,
        },
        'holiday_rate': {
          'first_8_hours_multiplier': _first8HoursMultiplier,
          'ninth_hour_multiplier': _ninthHourMultiplier,
          'tenth_plus_multiplier': _tenthPlusMultiplier,
          'is_active': true,
        },
      };

      await _rateService.updateOvertimeRates(
        newRates: ratesData,
        updatedBy: _auth.currentUser?.email ?? 'system',
      );

      // Reload data
      await _loadData();
      
      if (mounted) {
        _showSnackbar('Tarif lembur berhasil disimpan');
      }

    } catch (e) {
      logger.e('Error saving rates: $e');
      if (mounted) {
        _showSnackbar('Gagal menyimpan tarif', isError: true);
      }
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatRupiah(double value) {
    return OvertimeRateService.formatRupiahFull(value);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _gajiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          'Tarif Lembur',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      // 🔥 BOTTOM NAV: layar ini khusus superadmin (dibatasi di router)
      bottomNavigationBar: const AppBottomNav(
        userRole: 'superadmin',
        currentIndex: 2, // TODO: sesuaikan index tab "Penataan/Settings" kalau beda
      ),
      body: isLoading
          ? _buildLoadingState()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Gaji Card
                    _buildSalaryCard(),
                    const SizedBox(height: 16),
                    
                    // Weekday Rate Card
                    _buildRateCard(
                      title: 'Hari Kerja',
                      subtitle: 'Senin - Jumat',
                      color: const Color(0xFF2196F3),
                      icon: Icons.business_center,
                      firstLabel: 'Jam ke-1',
                      firstValue: _firstHourMultiplier,
                      nextLabel: 'Jam ke-2+',
                      nextValue: _nextHoursMultiplier,
                      onEdit: () => _showEditDialog2(
                        title: 'Edit Tarif Hari Kerja',
                        initialValue1: _firstHourMultiplier,
                        initialValue2: _nextHoursMultiplier,
                        label1: 'Multiplier Jam ke-1',
                        label2: 'Multiplier Jam ke-2+',
                        onSave: (v1, v2) {
                          setState(() {
                            _firstHourMultiplier = v1;
                            _nextHoursMultiplier = v2;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Holiday Rate Card
                    _buildRateCard(
                      title: 'Hari Libur',
                      subtitle: 'Sabtu, Minggu & Tanggal Merah',
                      color: const Color(0xFF4CAF50),
                      icon: Icons.celebration,
                      firstLabel: '8 jam pertama',
                      firstValue: _first8HoursMultiplier,
                      nextLabel: 'Jam ke-9',
                      nextValue: _ninthHourMultiplier,
                      extraLabel: 'Jam ke-10+',
                      extraValue: _tenthPlusMultiplier,
                      onEdit: () => _showEditDialog3(
                        title: 'Edit Tarif Hari Libur',
                        initialValue1: _first8HoursMultiplier,
                        initialValue2: _ninthHourMultiplier,
                        initialValue3: _tenthPlusMultiplier,
                        label1: 'Multiplier 8 jam pertama',
                        label2: 'Multiplier Jam ke-9',
                        label3: 'Multiplier Jam ke-10+',
                        onSave: (v1, v2, v3) {
                          setState(() {
                            _first8HoursMultiplier = v1;
                            _ninthHourMultiplier = v2;
                            _tenthPlusMultiplier = v3;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Summary
                    _buildSummaryCard(),
                    const SizedBox(height: 16),
                    
                    // History
                    if (_rateHistory.isNotEmpty) _buildHistorySection(),
                    const SizedBox(height: 16),
                    
                    // Save Button
                    _buildSaveButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF1E3C72),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat tarif lembur...',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard() {
    final gajiBersih = double.parse(
      _gajiController.text.replaceAll(RegExp(r'[^\d]'), '') == ''
          ? '0'
          : _gajiController.text.replaceAll(RegExp(r'[^\d]'), ''),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments,
                  color: Color(0xFF1E3C72),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Gaji Pokok Bulanan',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _gajiController,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E3C72),
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[400],
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Gaji tidak boleh kosong';
                    }
                    final number = value.replaceAll(RegExp(r'[^\d]'), '');
                    if (number.isEmpty) {
                      return 'Masukkan nominal yang valid';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final number = value.replaceAll(RegExp(r'[^\d]'), '');
                    if (number.isNotEmpty) {
                      final formatted = NumberFormat('#,###').format(
                        int.parse(number),
                      );
                      _gajiController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '/bulan',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3C72).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upah per jam',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatRupiah(gajiBersih / 173),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF1E3C72),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required String firstLabel,
    required double firstValue,
    required String nextLabel,
    required double nextValue,
    String? extraLabel,
    double? extraValue,
    required VoidCallback onEdit,
  }) {
    final hasExtra = extraLabel != null && extraValue != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Aktif',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildRateRow(firstLabel, '${firstValue.toStringAsFixed(1)}x', color),
                const SizedBox(height: 8),
                _buildRateRow(nextLabel, '${nextValue.toStringAsFixed(1)}x', color),
                if (hasExtra) ...[
                  const SizedBox(height: 8),
                  _buildRateRow(extraLabel!, '${extraValue!.toStringAsFixed(1)}x', color),
                ],
                const Divider(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit, size: 14, color: color),
                    label: Text(
                      'Ubah',
                      style: GoogleFonts.poppins(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              'Upah per Jam',
              _formatRupiah(_upahPerJam),
              Icons.access_time,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          Expanded(
            child: _buildSummaryItem(
              'Tarif Terakhir',
              DateFormat('dd/MM/yyyy').format(DateTime.now()),
              Icons.update,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 18, color: Color(0xFF9C27B0)),
              const SizedBox(width: 8),
              Text(
                'Riwayat Perubahan',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._rateHistory.take(3).map((history) {
            final changedAt = history['changed_at'] as DateTime;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3C72),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatRupiah(history['base_salary'] as double),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'By: ${history['changed_by']}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yy HH:mm').format(changedAt),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_rateHistory.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  '+ ${_rateHistory.length - 3} perubahan lainnya',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isSaving ? null : _saveRates,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Simpan Tarif Lembur',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // ==================== EDIT DIALOGS ====================
  
  // For 2 parameters (Weekday)
  void _showEditDialog2({
    required String title,
    required double initialValue1,
    required double initialValue2,
    required String label1,
    required String label2,
    required void Function(double, double) onSave,
  }) {
    final controller1 = TextEditingController(text: initialValue1.toStringAsFixed(1));
    final controller2 = TextEditingController(text: initialValue2.toStringAsFixed(1));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller1, label1),
              const SizedBox(height: 10),
              _buildTextField(controller2, label2),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final v1 = double.parse(controller1.text);
                final v2 = double.parse(controller2.text);
                onSave(v1, v2);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3C72),
            ),
            child: Text('Simpan', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  // For 3 parameters (Holiday)
  void _showEditDialog3({
    required String title,
    required double initialValue1,
    required double initialValue2,
    required double initialValue3,
    required String label1,
    required String label2,
    required String label3,
    required void Function(double, double, double) onSave,
  }) {
    final controller1 = TextEditingController(text: initialValue1.toStringAsFixed(1));
    final controller2 = TextEditingController(text: initialValue2.toStringAsFixed(1));
    final controller3 = TextEditingController(text: initialValue3.toStringAsFixed(1));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller1, label1),
              const SizedBox(height: 10),
              _buildTextField(controller2, label2),
              const SizedBox(height: 10),
              _buildTextField(controller3, label3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final v1 = double.parse(controller1.text);
                final v2 = double.parse(controller2.text);
                final v3 = double.parse(controller3.text);
                onSave(v1, v2, v3);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3C72),
            ),
            child: Text('Simpan', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'x',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: GoogleFonts.poppins(fontSize: 12),
      ),
      keyboardType: TextInputType.number,
      style: GoogleFonts.poppins(fontSize: 13),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Masukkan multiplier';
        }
        final mult = double.tryParse(value);
        if (mult == null || mult < 1) {
          return 'Multiplier minimal 1';
        }
        return null;
      },
    );
  }
}