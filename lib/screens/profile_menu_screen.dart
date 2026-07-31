// screens/profile/profile_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../../widgets/bottom_nav/app_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? userData;
  String? userId;
  String? userEmail;
  String? userName;
  String? userPhotoUrl;
  String? _userRole;
  File? _selectedImage;

  bool isEditing = false;
  bool isLoading = true;
  bool isSaving = false;

  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedFungsi = "operation";

  // 🔥 HAPUS: stats Map
  // Hanya simpan memberSince
  String _memberSince = '';

  static const Color primaryBlue = Color(0xFF1E3C72);
  static const Color accentOrange = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      userId = user.uid;
      userEmail = user.email;
      userPhotoUrl = user.photoURL;
      await _loadUserData();
      // 🔥 HAPUS: _loadUserStats() dipanggil
    } else {
      if (mounted) context.go('/login');
    }
  }

  Future<void> _loadUserData() async {
    if (userId == null) return;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        
        // 🔥 Parse memberSince
        String memberSince = '';
        if (data['created_at'] != null) {
          try {
            final createdAt = data['created_at'];
            DateTime date;
            if (createdAt is Timestamp) {
              date = createdAt.toDate();
            } else if (createdAt is String) {
              date = DateTime.parse(createdAt);
            } else {
              date = DateTime.now();
            }
            memberSince = DateFormat('MMMM yyyy', 'id_ID').format(date);
          } catch (e) {
            memberSince = 'Baru';
          }
        }
        
        setState(() {
          userData = data;
          userName = data['nama_lengkap'] ?? userEmail?.split('@')[0] ?? 'User';
          _userRole = data['role']?.toString() ?? 'mitra';
          _namaController.text = userName ?? '';
          _phoneController.text = data['phone']?.toString() ?? '';
          _selectedFungsi = data['fungsi'] ?? 'operation';
          userPhotoUrl = data['photo_url'] ?? userPhotoUrl;
          _memberSince = memberSince; // 🔥 Simpan memberSince
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 🔥 HAPUS: method _loadUserStats() seluruhnya

  int _getCurrentNavIndex() {
    switch (_userRole) {
      case 'superadmin':
        return 2;
      case 'manager':
        return 2;
      case 'pengawas':
        return 3;
      case 'mitra':
        return 3;
      default:
        return 0;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);

    try {
      await _firestore.collection('users').doc(userId).update({
        'nama_lengkap': _namaController.text.trim(),
        'phone': _phoneController.text.trim(),
        'fungsi': _selectedFungsi,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          userName = _namaController.text.trim();
          isEditing = false;
        });
        _showSnackBar('✅ Profil berhasil diperbarui', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnackBar('❌ Gagal memperbarui profil', Colors.red);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() => _selectedImage = File(file.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 360;
        final horizontalPadding = screenWidth * 0.04;
        final avatarSize = isSmallScreen ? 70.0 : 90.0;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: Text(
              'Profil Saya',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 16 : 18,
              ),
            ),
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: isSmallScreen ? 18 : 20),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (!isLoading)
                isEditing
                    ? TextButton(
                        onPressed: () {
                          setState(() {
                            isEditing = false;
                            _namaController.text = userName ?? '';
                            _phoneController.text = userData?['phone']?.toString() ?? '';
                            _selectedFungsi = userData?['fungsi'] ?? 'operation';
                            _selectedImage = null;
                          });
                        },
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.edit_rounded, size: isSmallScreen ? 20 : 24),
                        onPressed: () => setState(() => isEditing = true),
                      ),
            ],
          ),
          bottomNavigationBar: _userRole != null
              ? AppBottomNav(
                  userRole: _userRole!,
                  currentIndex: _getCurrentNavIndex(),
                )
              : null,
          body: isLoading
              ? const Center(child: CircularProgressIndicator(color: primaryBlue))
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadUserData();
                    // 🔥 HAPUS: await _loadUserStats();
                  },
                  color: primaryBlue,
                  child: SafeArea(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        12,
                        horizontalPadding,
                        16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - kToolbarHeight - MediaQuery.of(context).padding.top,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeaderCard(avatarSize: avatarSize, isSmallScreen: isSmallScreen),
                              // 🔥 HAPUS: SizedBox + _buildStatsRow()
                              SizedBox(height: screenWidth * 0.03),
                              _buildFormCard(isSmallScreen: isSmallScreen),
                              SizedBox(height: screenWidth * 0.03),
                              _buildActionButtons(isSmallScreen: isSmallScreen),
                              const Spacer(),
                              // 🔥 GUNAKAN _memberSince langsung
                              if (_memberSince.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: screenWidth * 0.04),
                                  child: Text(
                                    'Anggota sejak $_memberSince',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 10 : 11,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ==================== HEADER CARD ====================
  Widget _buildHeaderCard({required double avatarSize, required bool isSmallScreen}) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: isEditing ? _pickImage : null,
            child: Stack(
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                            ? Image.network(
                                userPhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAvatar(avatarSize, isSmallScreen),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                              )
                            : _buildAvatar(avatarSize, isSmallScreen),
                  ),
                ),
                if (isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                      decoration: BoxDecoration(
                        color: accentOrange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentOrange.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: isSmallScreen ? 14 : 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          Text(
            userName ?? 'User',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallScreen ? 3 : 4),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 12,
              vertical: isSmallScreen ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userEmail ?? '-',
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 11,
                color: Colors.white.withOpacity(0.9),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double size, bool isSmallScreen) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Text(
          (userName?.isNotEmpty == true ? userName![0].toUpperCase() : 'U'),
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  // 🔥 HAPUS: method _buildStatsRow() seluruhnya
  // 🔥 HAPUS: method _buildStatCard() seluruhnya

  // ==================== FORM CARD ====================
  Widget _buildFormCard({required bool isSmallScreen}) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accentOrange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Informasi Pribadi',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildTextField(
              controller: _namaController,
              label: 'Nama Lengkap',
              icon: Icons.person_outline,
              enabled: isEditing,
              isSmallScreen: isSmallScreen,
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Wajib diisi'
                  : (v.length < 3 ? 'Terlalu pendek' : null),
            ),
            SizedBox(height: isSmallScreen ? 10 : 14),
            _buildTextField(
              controller: _phoneController,
              label: 'Nomor HP',
              icon: Icons.phone_android,
              enabled: isEditing,
              keyboardType: TextInputType.phone,
              isSmallScreen: isSmallScreen,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              prefix: '+62',
            ),
            SizedBox(height: isSmallScreen ? 10 : 14),
            _buildReadOnlyField(
              Icons.email_outlined,
              'Email',
              userEmail ?? '-',
              isSmallScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    required bool isSmallScreen,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? prefix,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        fontSize: isSmallScreen ? 13 : 14,
        color: enabled ? primaryBlue : Colors.grey[700],
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 12 : 13,
          color: Colors.grey[600],
        ),
        prefixIcon: prefix != null
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10 : 12),
                child: Text(
                  prefix,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: primaryBlue,
                  ),
                ),
              )
            : Icon(icon, size: isSmallScreen ? 18 : 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentOrange),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[300]!),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 14,
          vertical: isSmallScreen ? 12 : 14,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(IconData icon, String label, String value, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 14,
        vertical: isSmallScreen ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: isSmallScreen ? 18 : 20, color: Colors.grey[500]),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.lock, size: isSmallScreen ? 12 : 14, color: Colors.grey),
        ],
      ),
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons({required bool isSmallScreen}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEditing)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 12 : 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: isSaving
                  ? SizedBox(
                      width: isSmallScreen ? 18 : 20,
                      height: isSmallScreen ? 18 : 20,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_rounded, size: isSmallScreen ? 18 : 20),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        Text(
                          'Simpan Perubahan',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                      ],
                    ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 12 : 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: isSmallScreen ? 18 : 20),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Text(
                    'Keluar dari Aplikasi',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 13 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}