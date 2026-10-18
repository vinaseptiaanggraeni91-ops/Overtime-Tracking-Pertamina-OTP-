import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Untuk debugPrint
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ResetPasswordScreen({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _emailSent = false;
  String _errorMessage = "";
  String? _sessionId;
  int _resendCooldown = 0;
  bool _canResend = true;
  Timer? _cooldownTimer;
  
  // 🔧 IMPROVEMENT: Debounce untuk mencegah double tap
  DateTime? _lastTapTime;
  static const _debounceDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  // ================= KIRIM RESET LINK =================
  Future<void> _sendResetLink() async {
    // 🔧 IMPROVEMENT: Debounce protection
    final now = DateTime.now();
    if (_lastTapTime != null && 
        now.difference(_lastTapTime!) < _debounceDuration) {
      return;
    }
    _lastTapTime = now;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_emailSent && !_canResend) {
      _showSnackBar(
        "Silakan tunggu ${_resendCooldown} detik untuk mengirim ulang",
        isSuccess: false,
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = "";
    });

    try {
      // 🔧 IMPROVEMENT: Gunakan session yang sama jika resend
      _sessionId ??= _authService.generateSessionId();

      final result = await _authService.sendResetPasswordEmail(
        email: _emailController.text.trim(),
        sessionId: _sessionId!,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _emailSent = true;
          _canResend = false;
          _resendCooldown = 60;
        });

        _startResendCooldown();
        _showSnackBar("Link reset password telah dikirim!", isSuccess: true);
      } else {
        // 🔧 IMPROVEMENT: Reset session ID jika gagal
        _sessionId = null;
        setState(() => _errorMessage = result.errorMessage);
      }
    } catch (e, stackTrace) {
      // 🔧 IMPROVEMENT: Detailed error logging
      debugPrint('❌ Error sending reset link: $e');
      debugPrint('📍 StackTrace: $stackTrace');
      
      if (!mounted) return;
      
      _sessionId = null;
      setState(() => _errorMessage = "Terjadi kesalahan. Silakan coba lagi.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  // ================= SNACKBAR =================
  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    
    // 🔧 IMPROVEMENT: Try-catch untuk mencegah crash
    try {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: isSuccess ? AppColors.primaryBlue : AppColors.softRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
    } catch (e) {
      debugPrint('❌ Error showing snackbar: $e');
    }
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(
          "Reset Password",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _loading ? null : () => context.pop(),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Icon Section
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    key: ValueKey(_emailSent),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _emailSent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
                      size: 60,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _emailSent ? "Cek Email Anda! 📧" : "Lupa Password?",
                    key: ValueKey(_emailSent),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Description
              Center(
                child: Text(
                  _emailSent
                      ? "Kami telah mengirimkan link reset password ke email Anda. Setelah mengubah password, klik tombol verifikasi di bawah."
                      : "Masukkan email yang terdaftar. Kami akan mengirimkan link untuk mereset password Anda.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              // Error message global
              if (_errorMessage.isNotEmpty && _emailSent) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.softRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.softRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.softRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: GoogleFonts.poppins(
                            color: AppColors.softRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Form or Confirmation
              if (!_emailSent) ...[
                _buildForm(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ] else ...[
                _buildConfirmationUI(),
              ],
              const SizedBox(height: 32),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Email Terdaftar",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _sendResetLink(),
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "contoh@email.com",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.email_outlined, color: AppColors.primaryBlue, size: 20),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.softRed),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.softRed, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
                  return _authService.validateEmail(v);
                },
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.softRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.softRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.softRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: GoogleFonts.poppins(
                            color: AppColors.softRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildActionButtons() => Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendResetLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                disabledBackgroundColor: AppColors.primaryBlue.withOpacity(0.6),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Kirim Link Reset",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: _loading ? null : () => context.pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Kembali ke Login",
                style: GoogleFonts.poppins(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildConfirmationUI() => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Email terkirim ke:",
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_rounded, color: AppColors.primaryBlue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _emailController.text,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Buka email Anda dan ketuk link di dalamnya —",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.primaryBlue.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "app akan terbuka otomatis untuk membuat password baru",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              // Sudah selesai buat password baru lewat link email? Langsung ke login.
              onPressed: _loading ? null : () => context.go('/login'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: BorderSide(color: AppColors.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Sudah Selesai, Ke Halaman Login",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _canResend
              ? TextButton(
                  onPressed: _loading ? null : _sendResetLink,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        "Kirim ulang email",
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryBlue,
                          decoration: TextDecoration.underline,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Kirim ulang dalam ${_resendCooldown}s",
                        style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _loading ? null : () => context.pop(),
            child: Text(
              "Kembali ke Login",
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      );

  Widget _buildInfoCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Langkah Reset Password",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoStep(1, "Masukkan email dan klik 'Kirim Link Reset'"),
            const SizedBox(height: 8),
            _infoStep(2, "Buka email Anda (cek juga folder spam)"),
            const SizedBox(height: 8),
            _infoStep(3, "Klik link reset password di email"),
            const SizedBox(height: 8),
            _infoStep(4, "Buat password baru di halaman browser"),
            const SizedBox(height: 8),
            _infoStep(5, "Kembali ke aplikasi dan klik 'Verifikasi Reset Password'"),
            const SizedBox(height: 8),
            _infoStep(6, "Sistem akan verifikasi dan arahkan ke login"),
          ],
        ),
      );

  Widget _infoStep(int number, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: AppColors.primaryBlue.withOpacity(0.8),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
}