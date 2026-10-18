// lib/screens/reset_password_confirm_screen.dart
//
// Layar ini dibuka lewat DEEP LINK dari email reset password
// (route '/reset-password', lihat catatan routing di bawah).
// Bertugas: validasi oobCode -> tampilkan form password baru ->
// terapkan langsung ke Firebase Auth via confirmPasswordReset().
//
// Ini menggantikan mekanisme lama yang menebak status reset dengan
// mencoba login pakai password palsu (auth_service.dart versi lama).
// Begitu applyPasswordReset() sukses, password SUDAH PASTI berubah.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/services/auth_service.dart';

class ResetPasswordConfirmScreen extends StatefulWidget {
  /// oobCode dari query parameter link (?oobCode=...&mode=resetPassword)
  final String oobCode;

  const ResetPasswordConfirmScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordConfirmScreen> createState() => _ResetPasswordConfirmScreenState();
}

enum _ScreenState { checking, invalidLink, form, success }

class _ResetPasswordConfirmScreenState extends State<ResetPasswordConfirmScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ScreenState _state = _ScreenState.checking;
  String _email = '';
  String _errorMessage = '';
  bool _submitting = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _checkCode();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkCode() async {
    if (widget.oobCode.isEmpty) {
      setState(() {
        _state = _ScreenState.invalidLink;
        _errorMessage = 'Link reset password tidak lengkap.';
      });
      return;
    }

    final result = await _authService.checkPasswordResetCode(widget.oobCode);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _email = result.email ?? '';
        _state = _ScreenState.form;
      });
    } else {
      setState(() {
        _state = _ScreenState.invalidLink;
        _errorMessage = result.errorMessage;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = '';
    });

    final result = await _authService.applyPasswordReset(
      oobCode: widget.oobCode,
      newPassword: _newPasswordController.text.trim(),
    );

    if (!mounted) return;

    if (result.success) {
      setState(() => _state = _ScreenState.success);
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Buat Password Baru', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_state) {
            _ScreenState.checking => _buildChecking(),
            _ScreenState.invalidLink => _buildInvalidLink(),
            _ScreenState.form => _buildForm(),
            _ScreenState.success => _buildSuccess(),
          },
        ),
      ),
    );
  }

  Widget _buildChecking() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildInvalidLink() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_off_rounded, color: AppColors.softRed, size: 56),
          const SizedBox(height: 16),
          Text(
            'Link Tidak Valid',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/reset-password-request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Minta Link Baru', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Text(
            'Buat password baru untuk',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          Text(
            _email,
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'Password Baru',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Password wajib diisi';
              if (v.length < 8) return 'Minimal 8 karakter';
              if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'[0-9]').hasMatch(v)) {
                return 'Kombinasikan huruf dan angka';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Ulangi Password Baru',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (value) {
              if (value != _newPasswordController.text) return 'Password tidak sama';
              return null;
            },
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_errorMessage, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.softRed)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: AppColors.primaryBlue.withOpacity(0.6),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Simpan Password Baru', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          Text(
            'Password Berhasil Diubah! 🎉',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Silakan login dengan password baru Anda.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Ke Halaman Login', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
