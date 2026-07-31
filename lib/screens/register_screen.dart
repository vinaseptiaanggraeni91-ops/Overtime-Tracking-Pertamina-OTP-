// lib/screens/register_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/services/auth_service.dart';
import '../../core/services/superadmin_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ================= CONTROLLER =================
  final _formKey = GlobalKey<FormState>();
  final _idPekerjaController = TextEditingController();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // ================= STATE =================
  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _loading = false;

  String _selectedFungsi = "operation";
  bool _showPasswordStrength = false;
  double _passwordStrength = 0.0;
  String _passwordStrengthText = "";
  Color _passwordStrengthColor = Colors.grey;

  // Validasi ID Pekerja
  bool _isValidatingWorker = false;
  bool _workerValidated = false;
  Map<String, dynamic>? _validatedWorker;
  String _workerValidationMessage = '';

  // ================= RATE LIMITING =================
  int _registerAttempts = 0;
  DateTime? _lastRegisterAttempt;
  Timer? _coolDownTimer;
  static const int _maxAttempts = 3;
  static const int _coolDownSeconds = 30;

  // ================= SERVICE =================
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();
  late String _sessionId;

  // ================= ANIMATION =================
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ================= FUNGSI LIST =================
  final List<Map<String, String>> _fungsiList = [
    {"value": "operation",   "label": "Operation",      "icon": "⚙️", "description": "Operasional Lapangan"},
    {"value": "maintenance", "label": "Maintenance",     "icon": "🔧", "description": "Perawatan & Perbaikan"},
    {"value": "hsse",        "label": "HSSE",            "icon": "🛡️", "description": "Keselamatan & K3"},
    {"value": "gpr",         "label": "GPR",             "icon": "📊", "description": "General Processing"},
    {"value": "bs",          "label": "Business Support","icon": "📋", "description": "Business Support"},
  ];

  // ================= LIFECYCLE =================
  @override
  void initState() {
    super.initState();
    
    // Setup animasi yang selaras dengan LoginScreen
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    
    _passwordController.addListener(_calculatePasswordStrength);
    _sessionId = _authService.generateSessionId();
    _idPekerjaController.addListener(() {
      if (_workerValidated) {
        setState(() {
          _workerValidated = false;
          _validatedWorker = null;
          _workerValidationMessage = '';
        });
      }
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_calculatePasswordStrength);
    _idPekerjaController.dispose();
    _namaController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _coolDownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ================= PASSWORD STRENGTH =================
  void _calculatePasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      if (_showPasswordStrength) {
        setState(() { _showPasswordStrength = false; _passwordStrength = 0.0; });
      }
      return;
    }

    setState(() {
      _showPasswordStrength = true;
      double strength = 0.0;
      if (password.length >= 8) strength += 0.25;
      if (password.length >= 10) strength += 0.15;
      if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
      if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
      if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
      _passwordStrength = strength.clamp(0.0, 1.0);

      if (_passwordStrength < 0.5) {
        _passwordStrengthText = "Lemah";
        _passwordStrengthColor = AppColors.softRed;
      } else if (_passwordStrength < 0.8) {
        _passwordStrengthText = "Sedang";
        _passwordStrengthColor = AppColors.accentOrange;
      } else {
        _passwordStrengthText = "Kuat";
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  // ================= VALIDASI ID PEKERJA =================
  Future<void> _validateWorkerId() async {
    final idPekerja = _idPekerjaController.text.trim();

    if (idPekerja.isEmpty) {
      _showError("ID Pekerja tidak boleh kosong");
      return;
    }

    setState(() {
      _isValidatingWorker = true;
      _workerValidated = false;
      _validatedWorker = null;
      _workerValidationMessage = '';
    });

    try {
      final result = await _dashboardService.validateWorkerId(idPekerja);

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _isValidatingWorker = false;
          _workerValidated = true;
          _validatedWorker = result;
          _workerValidationMessage = '✅ ID Valid - ${result['nama']}';
        });

        _namaController.text = result['nama'] ?? '';
        
        if (result['fungsi'] != null && result['fungsi'].toString().isNotEmpty) {
          setState(() {
            _selectedFungsi = result['fungsi'].toString();
          });
        }

        _showSuccess("ID Pekerja valid: ${result['nama']}");
      } else {
        setState(() {
          _isValidatingWorker = false;
          _workerValidated = false;
          _validatedWorker = null;
          _workerValidationMessage = '❌ ID Pekerja tidak ditemukan';
        });
        _showError("ID Pekerja tidak ditemukan di database. Hubungi admin.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingWorker = false;
        _workerValidated = false;
        _workerValidationMessage = '❌ Gagal validasi';
      });
      _showError("Gagal validasi ID Pekerja. Periksa koneksi Anda.");
    }
  }

  // ================= RATE LIMITING =================
  int _getCooldownRemaining() {
    if (_lastRegisterAttempt == null) return 0;
    final remaining = _coolDownSeconds - DateTime.now().difference(_lastRegisterAttempt!).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _startCooldownTimer() {
    _coolDownTimer?.cancel();
    _coolDownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_getCooldownRemaining() <= 0) {
        _coolDownTimer?.cancel();
        if (mounted) {
          setState(() {
            _registerAttempts = 0;
          });
        }
      }
      if (mounted) setState(() {});
    });
  }

  // ================= PROSES REGISTER =================
  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final remaining = _getCooldownRemaining();
    if (remaining > 0) {
      _showError("Terlalu banyak percobaan. Tunggu $remaining detik.");
      return;
    }
    if (_registerAttempts >= _maxAttempts) {
      _showError("Terlalu banyak percobaan. Silakan tunggu $_coolDownSeconds detik.");
      _registerAttempts = _maxAttempts;
      _lastRegisterAttempt = DateTime.now();
      _startCooldownTimer();
      return;
    }

    if (!_workerValidated) {
      _showError("ID Pekerja harus divalidasi terlebih dahulu. Klik tombol Validasi.");
      return;
    }

    if (_validatedWorker?['id_pekerja'] != _idPekerjaController.text.trim()) {
      _showError("ID Pekerja berubah. Silakan validasi ulang.");
      return;
    }

    final formError = _authService.validateRegisterForm(
      nama: _namaController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );
    if (formError != null) {
      _showError(formError);
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      _showError("Password dan konfirmasi tidak sama");
      return;
    }

    if (_passwordStrength < 0.5) {
      _showError("Password terlalu lemah. Kombinasikan huruf besar, kecil, dan angka.");
      return;
    }

    setState(() {
      _registerAttempts++;
      _loading = true;
    });
    _lastRegisterAttempt = DateTime.now();

    try {
      final result = await _authService.register(
        idPekerja: _idPekerjaController.text.trim(),
        nama: _namaController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        fungsi: _selectedFungsi,
        sessionId: _sessionId,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (result.success) {
        setState(() {
          _registerAttempts = 0;
        });
        await _showSuccessDialog();
      } else {
        setState(() {
          _registerAttempts--;
        });
        _showError(result.message);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _registerAttempts--;
      });
      _showError(_getFirebaseErrorMessage(e.code));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _registerAttempts--;
      });
      _showError("Koneksi timeout. Periksa jaringan Anda.");
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _registerAttempts--;
      });
      debugPrint("Registrasi error: $e");
      _showError("Terjadi kesalahan sistem. Silakan coba lagi.");
    }
  }

  // ================= POPUP SUKSES =================
  Future<void> _showSuccessDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon container
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF059669),
                      Color(0xFF047857),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Registrasi Berhasil! 🎉",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Akun Anda telah berhasil dibuat.\nSilakan login dengan akun yang telah dibuat.",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3C72),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Masuk Sekarang",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      context.go('/login');
    }
  }

  // ================= ERROR & SUCCESS SNACKBAR =================
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.softRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Email sudah terdaftar.\nSilakan login atau gunakan email lain.';
      case 'invalid-email':        return 'Format email tidak valid.\nContoh: nama@email.com';
      case 'weak-password':        return 'Password terlalu lemah.\nGunakan minimal 6 karakter.';
      case 'operation-not-allowed': return 'Pendaftaran belum diaktifkan.\nHubungi admin.';
      default:                     return 'Pendaftaran gagal. Silakan coba lagi.';
    }
  }

  // =========================================================
  // 🔥 UI BUILD - SELARAS DENGAN LOGIN SCREEN
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallHeight = size.height < 700;
    final remaining = _getCooldownRemaining();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFEFF6FF),
              Color(0xFFF0F9FF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  
                  // 🔥 HEADER DENGAN BACK BUTTON
                  _buildHeader(),
                  
                  SizedBox(height: isSmallHeight ? 16 : 24),
                  
                  // 🔥 ILUSTRASI REGISTER
                  _buildRegisterIllustration(isSmallHeight),
                  
                  SizedBox(height: isSmallHeight ? 20 : 28),
                  
                  // 🔥 WELCOME TEXT
                  _buildWelcomeText(),
                  
                  SizedBox(height: isSmallHeight ? 16 : 24),
                  
                  // 🔥 REGISTER CARD
                  _buildRegisterCard(remaining),
                  
                  SizedBox(height: isSmallHeight ? 20 : 28),
                  
                  // 🔥 FOOTER
                  _buildFooter(),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // 🔥 HEADER
  // =========================================================
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button dengan glass effect
        GestureDetector(
          onTap: () => context.go('/login'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.primaryBlue,
            ),
          ),
        ),

        // Logo container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.06),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade100,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo_pertamina.png',
                  height: 30,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 1.5,
                height: 24,
                color: Colors.grey.shade300,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // 🔥 ILUSTRASI REGISTER - MODERN
  // =========================================================
  Widget _buildRegisterIllustration(bool isSmallHeight) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          height: isSmallHeight ? 140 : 180,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF059669).withOpacity(0.06),
                const Color(0xFF047857).withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF059669).withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF059669).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF047857).withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Main illustration
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon container dengan tema register (hijau)
                    Container(
                      width: isSmallHeight ? 64 : 80,
                      height: isSmallHeight ? 64 : 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF059669),
                            Color(0xFF047857),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.app_registration_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    
                    SizedBox(height: isSmallHeight ? 12 : 16),
                    
                    // Security badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 14,
                            color: const Color(0xFF059669),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Verifikasi ID Pekerja",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // 🔥 WELCOME TEXT
  // =========================================================
  Widget _buildWelcomeText() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add_rounded,
                  size: 14,
                  color: const Color(0xFF059669),
                ),
                const SizedBox(width: 6),
                Text(
                  "Overtime Tracking Pertamina",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF059669),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            "Daftar Akun Baru 👤",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
              height: 1.2,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            "Verifikasi ID Pekerja TAD Anda\nuntuk membuat akun baru",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 🔥 REGISTER CARD - GLASSMORPHISM
  // =========================================================
  Widget _buildRegisterCard(int remaining) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E3C72),
                Color(0xFF2A5298),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3C72).withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Form header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.app_registration_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Registrasi",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                Text(
                  "Verifikasi ID Pekerja terlebih dahulu",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Cooldown banner
                if (remaining > 0) _buildCooldownBanner(remaining),
                
                // ID Pekerja field
                _buildIdPekerjaField(),
                
                // Validation info
                if (_workerValidationMessage.isNotEmpty) _buildValidationInfo(),
                
                const SizedBox(height: 12),
                
                // Nama field
                _buildNamaField(),
                
                const SizedBox(height: 12),
                
                // Email field
                _buildEmailField(),
                
                const SizedBox(height: 12),
                
                // Phone field
                _buildPhoneField(),
                
                const SizedBox(height: 12),
                
                // Password field
                _buildPasswordField(),
                
                // Password strength
                if (_showPasswordStrength) _buildPasswordStrength(),
                
                const SizedBox(height: 12),
                
                // Confirm password
                _buildConfirmPasswordField(),
                
                const SizedBox(height: 16),
                
                // Fungsi field
                _buildFungsiField(),
                
                const SizedBox(height: 24),
                
                // Register button
                _buildRegisterButton(remaining),
                
                const SizedBox(height: 16),
                
                // Login link
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // COOLDOWN BANNER
  // =========================================================
  Widget _buildCooldownBanner(int remaining) {
    final progress = remaining > 0
        ? 1.0 - (remaining / _coolDownSeconds)
        : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Terlalu banyak percobaan",
                  style: GoogleFonts.poppins(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.orange.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Silakan tunggu $remaining detik",
            style: GoogleFonts.poppins(
              color: Colors.orange.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ID PEKERJA FIELD
  // =========================================================
  Widget _buildIdPekerjaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("ID Pekerja"),
        const SizedBox(height: 6),
        TextFormField(
          controller: _idPekerjaController,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: _inputDecoration(
            hint: "Masukkan ID Pekerja",
            icon: Icons.badge_rounded,
          ).copyWith(
            suffixIcon: _buildValidateButton(),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return "ID Pekerja wajib diisi";
            if (!_workerValidated) return "ID Pekerja harus divalidasi";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildValidateButton() {
    if (_isValidatingWorker) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      );
    }

    if (_workerValidated) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: 22,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Container(
        margin: const EdgeInsets.all(4),
        child: TextButton(
          onPressed: _validateWorkerId,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            backgroundColor: Colors.white.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            "Validasi",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValidationInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _workerValidated
            ? Colors.green.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _workerValidated
              ? Colors.greenAccent.withOpacity(0.4)
              : Colors.redAccent.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _workerValidated ? Icons.verified_rounded : Icons.warning_rounded,
            color: _workerValidated ? Colors.greenAccent : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _workerValidationMessage,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FORM FIELDS
  // =========================================================
  Widget _buildNamaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Nama Lengkap"),
        const SizedBox(height: 6),
        TextFormField(
          controller: _namaController,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(
            hint: "Masukkan nama lengkap",
            icon: Icons.person_outline_rounded,
          ),
          validator: (v) => _authService.validateNama(v),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Email"),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(
            hint: "contoh@email.com",
            icon: Icons.email_outlined,
          ),
          validator: (v) => _authService.validateEmail(v),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Nomor HP"),
        const SizedBox(height: 6),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(
            hint: "081234567890",
            icon: Icons.phone_iphone_rounded,
          ),
          validator: (v) => _authService.validatePhone(v),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Password"),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passwordController,
          obscureText: _hidePass,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(
            hint: "Buat password",
            icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePass = !_hidePass),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _hidePass
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 18,
                ),
              ),
            ),
          ),
          validator: (v) => _authService.validatePassword(v),
        ),
      ],
    );
  }

  Widget _buildPasswordStrength() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _passwordStrength,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _passwordStrengthText,
                style: GoogleFonts.poppins(
                  color: _passwordStrengthColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Minimal 8 karakter: Huruf besar, kecil, angka",
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Konfirmasi Password"),
        const SizedBox(height: 6),
        TextFormField(
          controller: _confirmController,
          obscureText: _hideConfirm,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(
            hint: "Ulangi password Anda",
            icon: Icons.lock_reset_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _hideConfirm
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 18,
                ),
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return "Wajib diisi";
            if (v != _passwordController.text) return "Password tidak cocok";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFungsiField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Fungsi Kerja"),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFungsi,
              isExpanded: true,
              icon: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white,
                ),
              ),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
              ),
              dropdownColor: const Color(0xFF1E3C72),
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              items: _fungsiList.map((item) {
                return DropdownMenuItem<String>(
                  value: item['value'],
                  child: Row(
                    children: [
                      Text(
                        item['icon']!,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['label']!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item['description']!,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
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
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedFungsi = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // REGISTER BUTTON
  // =========================================================
  Widget _buildRegisterButton(int remaining) {
    final isDisabled = _loading || remaining > 0 || !_workerValidated;

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isDisabled
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF1F5F9),
                ],
              ),
        boxShadow: isDisabled
            ? []
            : [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isDisabled ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: Colors.white.withOpacity(0.1),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1E3C72),
                ),
              )
            : remaining > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Tunggu $remaining detik",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Daftar Sekarang",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: const Color(0xFF1E3C72),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3C72).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Color(0xFF1E3C72),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // =========================================================
  // LOGIN LINK
  // =========================================================
  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Sudah punya akun? ",
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        GestureDetector(
          onTap: () => context.go('/login'),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              "Masuk Sekarang",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // FOOTER
  // =========================================================
  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          "© 2026 Overtime Tracking Pertamina",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "PT Pertamina (Persero) - All Rights Reserved",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: const Color(0xFFCBD5E1),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // HELPER METHODS
  // =========================================================
  
  Widget _buildLabel(String text) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Text(
          " *",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: Colors.white.withOpacity(0.4),
        fontSize: 13,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 18,
        ),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
      errorStyle: GoogleFonts.poppins(
        fontSize: 10,
        color: Colors.redAccent,
      ),
    );
  }
}