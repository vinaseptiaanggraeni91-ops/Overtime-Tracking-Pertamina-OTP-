// lib/screens/login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../core/services/auth_service.dart';
import '../core/services/push_notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ================= SERVICE =================
  final AuthService _authService = AuthService();

  // ================= FORM =================
  final _formKey = GlobalKey<FormState>();

  // ================= CONTROLLER =================
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();

  // ================= STATE =================
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String _errorMessage = "";

  // ================= RATE LIMIT =================
  int _loginAttempts = 0;
  Timer? _coolDownTimer;
  int _cooldownRemaining = 0;

  static const int _maxAttempts = 3;
  static const int _coolDownSeconds = 30;

  // ================= ANIMATION =================
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 🔥 TAMBAHKAN: Flag untuk mencegah auto login jika ada intent khusus
  bool _shouldAutoLogin = true;

  @override
  void initState() {
    super.initState();
    
    // Setup animasi
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
    
    _loadRememberMe();
    
    // 🔥 HANYA AUTO LOGIN JIKA TIDAK ADA INTENT KHUSUS
    _checkAutoLoginIfNeeded();
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    _coolDownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // =========================================================
  // REMEMBER ME
  // =========================================================

  Future<void> _loadRememberMe() async {
    final data = await _authService.loadRememberMe();

    if (!mounted) return;

    setState(() {
      _rememberMe = data.remembered;

      if (data.remembered && data.identity.isNotEmpty) {
        _identityController.text = data.identity;
      }
    });
  }

  // =========================================================
  // 🔥 AUTO LOGIN - DIPERBAIKI
  // =========================================================

  Future<void> _checkAutoLoginIfNeeded() async {
    // 🔥 Cek apakah ada intent khusus (reset password, dll)
    // Jika ada, skip auto login
    if (!_shouldAutoLogin) {
      debugPrint('🔄 Auto login skipped - special intent detected');
      return;
    }

    // 🔥 Cek apakah user sebelumnya sudah login
    final result = await _authService.tryAutoLogin();

    if (!mounted) return;

    if (result != null && result.success) {
      _showSuccess("Selamat datang kembali, ${result.nama}!");

      // 🔔 PENTING: sama seperti login manual, auto-login juga wajib
      // refresh token FCM — ini yang selama ini KELEWAT, makanya token
      // di Firestore bisa basi walau user rutin buka app via auto-login.
      unawaited(
        PushNotificationService().refreshToken().catchError((e) {
          debugPrint('⚠️ Gagal refresh FCM token setelah auto-login: $e');
        }),
      );

      // 🔥 Delay sebentar agar animasi sempat terlihat
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _navigateToDashboard(result.role);
      }
    }
  }

  // =========================================================
  // RATE LIMIT
  // =========================================================

  bool get _isBlocked => _cooldownRemaining > 0;

  void _startCooldown() {
    _cooldownRemaining = _coolDownSeconds;

    _coolDownTimer?.cancel();

    _coolDownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _cooldownRemaining--;
        });

        if (_cooldownRemaining <= 0) {
          timer.cancel();

          setState(() {
            _cooldownRemaining = 0;
            _loginAttempts = 0;
          });
        }
      },
    );
  }

  void _resetCooldown() {
    _coolDownTimer?.cancel();

    setState(() {
      _cooldownRemaining = 0;
      _loginAttempts = 0;
    });
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final formError = _authService.validateLoginForm(
      _identityController.text,
      _passwordController.text,
    );

    if (formError != null) {
      _showError(formError);
      return;
    }

    if (_isBlocked) {
      _showError(
        "Terlalu banyak percobaan. Tunggu $_cooldownRemaining detik.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _loginAttempts++;
    });

    try {
      final result = await _authService.login(
        identity: _identityController.text.trim(),
        password: _passwordController.text,
        sessionId: _authService.generateSessionId(),
        rememberMe: _rememberMe,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        _resetCooldown();

        _showSuccess(
          "Selamat datang, ${result.nama}!",
        );

        // 🔔 PENTING: simpan/refresh token FCM device ini ke Firestore
        // setelah login berhasil. Tanpa ini, token FCM bisa jadi basi
        // (UNREGISTERED) walau user rutin login, karena token baru
        // dari device tidak pernah diberitahu ke server.
        // Tidak di-await biar navigasi ke dashboard tidak ketunda,
        // dan dibungkus try-catch biar gagal refresh token tidak
        // menggagalkan proses login itu sendiri.
        unawaited(
          PushNotificationService().refreshToken().catchError((e) {
            debugPrint('⚠️ Gagal refresh FCM token setelah login: $e');
          }),
        );

        _navigateToDashboard(result.role);
      } else {
        if (result.errorCode == 'network-request-failed' ||
            result.errorCode == 'timeout' ||
            result.errorCode == 'unknown') {
          _loginAttempts--;
        }

        setState(() {
          _errorMessage = result.errorMessage;
        });

        if (_loginAttempts >= _maxAttempts) {
          _startCooldown();

          _showError(
            "Terlalu banyak percobaan. Akun dikunci selama $_coolDownSeconds detik.",
          );
        } else {
          final remaining = _maxAttempts - _loginAttempts;

          _showError(
            "${result.errorMessage}\nSisa percobaan: $remaining kali.",
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loginAttempts--;
        _errorMessage = "Terjadi kesalahan sistem.";
      });

      debugPrint("Login Error: $e");

      _showError(
        "Terjadi kesalahan sistem. Silakan coba lagi.",
      );
    }
  }

  void _navigateToDashboard(String role) {
    final path = _authService.getDashboardPath(role);
    context.go(path);
  }

  void _showError(String message) {
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
                message,
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

  void _showSuccess(String message) {
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
        duration: const Duration(seconds: 3),
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
                message,
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallHeight = size.height < 700;

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
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  
                  // 🔥 HEADER DENGAN LOGO
                  _buildHeader(),
                  
                  SizedBox(height: isSmallHeight ? 16 : 24),
                  
                  // 🔥 ILUSTRASI MODERN
                  _buildModernIllustration(isSmallHeight),
                  
                  SizedBox(height: isSmallHeight ? 20 : 28),
                  
                  // 🔥 WELCOME TEXT
                  _buildWelcomeText(),
                  
                  SizedBox(height: isSmallHeight ? 16 : 24),
                  
                  // 🔥 LOGIN CARD
                  _buildLoginCard(),
                  
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
  // 🔥 HEADER DENGAN LOGO - MODERN & ELEGANT
  // =========================================================
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button dengan glass effect
        GestureDetector(
          onTap: () => context.pop(),
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

        // Logo container dengan background subtle
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
              // Logo Pertamina
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
              // Logo App
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
  // 🔥 ILUSTRASI MODERN DENGAN ANIMASI
  // =========================================================
  Widget _buildModernIllustration(bool isSmallHeight) {
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
                AppColors.primaryBlue.withOpacity(0.06),
                const Color(0xFF4B79A1).withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primaryBlue.withOpacity(0.08),
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
                        AppColors.primaryBlue.withOpacity(0.1),
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
                        const Color(0xFF4B79A1).withOpacity(0.08),
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
                    // Icon container
                    Container(
                      width: isSmallHeight ? 64 : 80,
                      height: isSmallHeight ? 64 : 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryBlue,
                            Color(0xFF4B79A1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.login_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    
                    SizedBox(height: isSmallHeight ? 12 : 16),
                    
                    // Security badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
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
  // 🔥 WELCOME TEXT - LEBIH HIERARKI
  // =========================================================
  Widget _buildWelcomeText() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Small badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Overtime Tracking Pertamina",
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            "Selamat Datang Kembali! 👋",
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
            "Silakan masuk untuk mengakses\ndashboard pengajuan lembur Anda",
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
  // 🔥 LOGIN CARD - GLASSMORPHISM & MODERN
  // =========================================================
  Widget _buildLoginCard() {
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
                // Form header dengan icon
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
                        Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Masuk ke Akun",
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
                  "Gunakan email terdaftar",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Cooldown banner
                if (_isBlocked) _buildCooldownBanner(),
                
                // Error message
                if (_errorMessage.isNotEmpty && !_isBlocked)
                  _buildErrorMessage(),
                
                // Identity field
                _buildIdentityField(),
                
                const SizedBox(height: 16),
                
                // Password field
                _buildPasswordField(),
                
                const SizedBox(height: 12),
                
                // Remember & Forgot
                _buildRememberAndForgot(),
                
                const SizedBox(height: 22),
                
                // Login button
                _buildLoginButton(),
                
                const SizedBox(height: 18),
                
                // Register link
                _buildRegisterLink(),
                
                // 🔥 TAMBAHKAN: Reset Aplikasi link
                const SizedBox(height: 12),
                _buildResetAppLink(),
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
  Widget _buildCooldownBanner() {
    final progress = _cooldownRemaining > 0
        ? 1.0 - (_cooldownRemaining / _coolDownSeconds)
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
            "Silakan tunggu $_cooldownRemaining detik",
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
  // ERROR MESSAGE
  // =========================================================
  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                color: Colors.red.shade300,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // IDENTITY FIELD
  // =========================================================
  Widget _buildIdentityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Email"),
        const SizedBox(height: 6),
        TextFormField(
          controller: _identityController,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: _inputDecoration(
            hint: "contoh@email.com",
            icon: Icons.person_outline_rounded,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Wajib diisi';
            }
            if (v.contains('@')) {
              return _authService.validateEmail(v);
            }
            return _authService.validatePhone(v);
          },
        ),
      ],
    );
  }

  // =========================================================
  // PASSWORD FIELD
  // =========================================================
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Password"),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: _inputDecoration(
            hint: "Masukkan password",
            icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _obscurePassword
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

  // =========================================================
  // REMEMBER & FORGOT
  // =========================================================
  Widget _buildRememberAndForgot() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _rememberMe = !_rememberMe;
            });
          },
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _rememberMe
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _rememberMe
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: _rememberMe
                    ? const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF1E3C72),
                        size: 14,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                "Ingat saya",
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            
            _shouldAutoLogin = false;
            final email = _identityController.text.trim();
            context.push('/reset-password-request?email=$email');
          },
          child: Text(
            "Lupa Password?",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // LOGIN BUTTON
  // =========================================================
  Widget _buildLoginButton() {
    final isDisabled = _isLoading || _isBlocked;

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
        onPressed: isDisabled ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: Colors.white.withOpacity(0.1),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1E3C72),
                ),
              )
            : _isBlocked
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Terkunci $_cooldownRemaining detik",
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
                        "Login",
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
  // REGISTER LINK
  // =========================================================
  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Belum punya akun? ",
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/register'),
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
              "Daftar Sekarang",
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
  // 🔥 RESET APLIKASI LINK - DITAMBAHKAN
  // =========================================================
  Widget _buildResetAppLink() {
    return GestureDetector(
      onTap: () {
        // 🔥 NONAKTIFKAN AUTO LOGIN SAAT NAVIGASI KE RESET APLIKASI
        _shouldAutoLogin = false;
        context.push('/reset-app');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh_rounded,
              color: Colors.white.withOpacity(0.6),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              "Reset Aplikasi",
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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