// lib/features/superadmin/widgets/quick_actions.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../core/services/superadmin_service.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A4F8C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withAlpha(77),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Aksi Cepat',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              Icon(Icons.flash_on, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          _QuickActionItem('Tambah User', Icons.person_add, Colors.blue,
              () => _showAddUserDialog(context)),
          const SizedBox(height: 12),
          _QuickActionItem('Broadcast', Icons.campaign, Colors.orange,
              () => _showBroadcastDialog(context)),
        ],
      ),
    );
  }

  // ==================== ADD USER DIALOG (FIXED) ====================
  void _showAddUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'mitra';
    String selectedFungsi = 'operation';
    final formKey = GlobalKey<FormState>();
    final authService = AuthService();
    final dashboardService = DashboardService();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text('Tambah User Baru'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nama
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      hintText: 'Masukkan nama lengkap',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                      if (v.trim().length < 3) return 'Minimal 3 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Email
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'contoh@email.com',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.email),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Phone
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Nomor HP',
                      hintText: '081234567890',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.phone),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                      final cleanPhone =
                          v.replaceAll(RegExp(r'[^\d]'), '');
                      if (cleanPhone.length < 10 || cleanPhone.length > 13) {
                        return 'Nomor HP 10-13 digit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Password
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Minimal 8 karakter',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.lock),
                      filled: true,
                      fillColor: Colors.grey[50],
                      helperText:
                          'Min 8 karakter, huruf besar, huruf kecil, angka',
                      helperMaxLines: 2,
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Wajib diisi';
                      if (v.length < 8) return 'Minimal 8 karakter';
                      if (!v.contains(RegExp(r'[A-Z]'))) {
                        return 'Harus ada huruf besar';
                      }
                      if (!v.contains(RegExp(r'[a-z]'))) {
                        return 'Harus ada huruf kecil';
                      }
                      if (!v.contains(RegExp(r'[0-9]'))) {
                        return 'Harus ada angka';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon:
                          const Icon(Icons.admin_panel_settings),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'superadmin',
                        child: Text('🛡️ Super Admin'),
                      ),
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text('👔 Manager'),
                      ),
                      DropdownMenuItem(
                        value: 'pengawas',
                        child: Text('👷 Pengawas'),
                      ),
                      DropdownMenuItem(
                        value: 'mitra',
                        child: Text('👤 Mitra'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedRole = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Fungsi Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedFungsi,
                    decoration: InputDecoration(
                      labelText: 'Fungsi',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.work),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'operation',
                          child: Text('⚙️ Operation')),
                      DropdownMenuItem(
                          value: 'maintenance',
                          child: Text('🔧 Maintenance')),
                      DropdownMenuItem(
                          value: 'hsse', child: Text('🛡️ HSSE')),
                      DropdownMenuItem(
                          value: 'gpr', child: Text('📊 GPR')),
                      DropdownMenuItem(
                          value: 'bs', child: Text('📋 Business Support')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedFungsi = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setState(() => isLoading = true);

                        try {
                          final result = await authService.createUser(
                            nama: nameController.text.trim(),
                            email: emailController.text.trim(),
                            phone: phoneController.text
                                .replaceAll(RegExp(r'[^\d]'), ''),
                            password: passwordController.text,
                            role: selectedRole,
                            fungsi: selectedFungsi,
                          );

                          if (!dialogContext.mounted) return;

                          if (result.success) {
                            // ✅ ADMIN TETAP LOGIN, tidak perlu re-login!
                            final sessionId =
                                dashboardService.generateSessionId();
                            await dashboardService.logActivity(
                              'user_added',
                              'Menambahkan ${selectedRole.toUpperCase()}: ${emailController.text.trim()}',
                              sessionId,
                            );

                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text('✅ ${result.message}')),
                                ]),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } else {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(dialogContext)
                                .showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.error,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text('❌ ${result.message}')),
                                ]),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('❌ Add user error: $e');
                          if (dialogContext.mounted) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(dialogContext)
                                .showSnackBar(
                              SnackBar(
                                content: Text('❌ Gagal: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      }
                    },
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add, size: 18),
              label: isLoading
                  ? const Text('Menyimpan...')
                  : const Text('Tambah User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BROADCAST DIALOG ====================
  void _showBroadcastDialog(BuildContext context) {
    final messageController = TextEditingController();
    String selectedRole = 'Semua';
    final formKey = GlobalKey<FormState>();
    final service = DashboardService();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.campaign_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Broadcast Pesan'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Pesan',
                    hintText: 'Masukkan pesan broadcast...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Pesan tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Target Role',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: [
                    'Semua',
                    'superadmin',
                    'manager',
                    'pengawas',
                    'mitra'
                  ]
                      .map((r) => DropdownMenuItem<String>(
                            value: r,
                            child: Text(r == 'Semua' ? r : r.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRole = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSending ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: isSending
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSending = true);
                        try {
                          final firestore = FirebaseFirestore.instance;
                          final message = messageController.text.trim();
                          final sessionId = service.generateSessionId();

                          await firestore.collection('broadcasts').add({
                            'message': message,
                            'targetRole': selectedRole,
                            'createdBy': FirebaseAuth
                                    .instance.currentUser?.email ??
                                'unknown',
                            'createdAt': FieldValue.serverTimestamp(),
                            'status': 'active',
                          });

                          Query userQuery =
                              firestore.collection('users');
                          if (selectedRole != 'Semua') {
                            userQuery = userQuery.where('role',
                                isEqualTo: selectedRole.toLowerCase());
                          }

                          final usersSnapshot =
                              await userQuery.limit(500).get();
                          final batch = firestore.batch();
                          int notifiedCount = 0;

                          for (var doc in usersSnapshot.docs) {
                            if (doc.id ==
                                FirebaseAuth
                                    .instance.currentUser?.uid) {
                              continue;
                            }
                            final notifRef = firestore
                                .collection('notifications')
                                .doc();
                            batch.set(notifRef, {
                              'userId': doc.id,
                              'title': '📢 Broadcast',
                              'body': message,
                              'type': 'broadcast',
                              'isRead': false,
                              'createdAt':
                                  FieldValue.serverTimestamp(),
                              'data': {'targetRole': selectedRole},
                            });
                            notifiedCount++;
                          }

                          if (notifiedCount > 0) {
                            await batch.commit();
                          }

                          await service.logActivity(
                            'broadcast',
                            'Broadcast ke $selectedRole ($notifiedCount user)',
                            sessionId,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '✅ Broadcast terkirim ke $notifiedCount user!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('❌ Broadcast error: $e');
                          if (dialogContext.mounted) {
                            setDialogState(() => isSending = false);
                            ScaffoldMessenger.of(dialogContext)
                                .showSnackBar(
                              SnackBar(
                                content:
                                    Text('❌ Gagal: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      }
                    },
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 18),
              label: isSending
                  ? const Text('Mengirim...')
                  : const Text('Kirim'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withAlpha(51), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}