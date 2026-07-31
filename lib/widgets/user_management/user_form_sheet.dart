// lib/features/superadmin/widgets/user_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/user_helpers.dart';

class UserFormSheet extends StatefulWidget {
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> availableWorkers;
  final Future<Map<String, dynamic>?> Function(String)? onValidateWorkerId;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  const UserFormSheet({
    super.key,
    this.user,
    this.availableWorkers = const [],
    this.onValidateWorkerId,
    required this.onSubmit,
  });

  static void show(
    BuildContext context, {
    Map<String, dynamic>? user,
    List<Map<String, dynamic>> availableWorkers = const [],
    Future<Map<String, dynamic>?> Function(String)? onValidateWorkerId,
    required Future<void> Function(Map<String, dynamic> data) onSubmit,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => UserFormSheet(
        user: user,
        availableWorkers: availableWorkers,
        onValidateWorkerId: onValidateWorkerId,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _idPekerjaCtrl;

  late String _role;
  late String _fungsi;
  late bool _isOfficerSafety;
  bool _isLoading = false;

  // ID Pekerja state
  String _idPekerjaQuery = '';
  List<Map<String, dynamic>> _filteredWorkers = [];
  Map<String, dynamic>? _selectedWorker;
  bool _isValidatingWorker = false;
  String? _workerValidationError;
  bool _showWorkerDropdown = false;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _idPekerjaFocus = FocusNode();

  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.user?['nama_lengkap'] ?? '');
    _emailCtrl = TextEditingController(text: widget.user?['email'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.user?['phone'] ?? '');
    _passCtrl = TextEditingController();
    _idPekerjaCtrl = TextEditingController(text: widget.user?['id_pekerja'] ?? '');
    _role = widget.user?['role'] ?? 'mitra';
    _fungsi = widget.user?['fungsi'] ?? 'operation';
    _isOfficerSafety = _role == 'officer_safety';
    _filteredWorkers = List.from(widget.availableWorkers);

    // Satu-satunya listener untuk perubahan teks ID Pekerja.
    // (Sebelumnya juga dipanggil via onChanged di TextFormField -> dobel trigger)
    _idPekerjaCtrl.addListener(_onIdPekerjaChanged);
    _idPekerjaFocus.addListener(() {
      if (!_idPekerjaFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showWorkerDropdown = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _idPekerjaCtrl.dispose();
    _idPekerjaFocus.dispose();
    super.dispose();
  }

  void _onIdPekerjaChanged() {
    final query = _idPekerjaCtrl.text.trim().toLowerCase();
    if (query == _idPekerjaQuery) return;

    setState(() {
      _idPekerjaQuery = query;
      _selectedWorker = null;
      _workerValidationError = null;
      _showWorkerDropdown = query.isNotEmpty;

      if (query.isEmpty) {
        _filteredWorkers = List.from(widget.availableWorkers);
      } else {
        _filteredWorkers = widget.availableWorkers.where((w) {
          final id = (w['id_pekerja'] ?? '').toString().toLowerCase();
          final nama = (w['nama'] ?? '').toString().toLowerCase();
          return id.contains(query) || nama.contains(query);
        }).toList();
      }
    });
  }

  void _selectWorker(Map<String, dynamic> worker) {
    setState(() {
      _selectedWorker = worker;
      _idPekerjaCtrl.text = worker['id_pekerja'] ?? '';
      _idPekerjaQuery = worker['id_pekerja'] ?? '';
      _showWorkerDropdown = false;
      _workerValidationError = null;
      _idPekerjaFocus.unfocus();
    });
  }

  Future<bool> _validateWorker() async {
    final idPekerja = _idPekerjaCtrl.text.trim();
    // ID Pekerja bersifat opsional untuk semua role -> kosong dianggap valid.
    if (idPekerja.isEmpty) return true;

    setState(() {
      _isValidatingWorker = true;
      _workerValidationError = null;
    });

    try {
      if (widget.onValidateWorkerId != null) {
        final result = await widget.onValidateWorkerId!(idPekerja);
        if (!mounted) return false;

        if (result == null) {
          setState(() {
            _workerValidationError = 'ID Pekerja tidak ditemukan';
            _isValidatingWorker = false;
          });
          return false;
        }

        setState(() {
          _selectedWorker = result;
          _isValidatingWorker = false;
        });
        return true;
      }
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _workerValidationError = 'Gagal validasi';
        _isValidatingWorker = false;
      });
      return false;
    }

    if (mounted) setState(() => _isValidatingWorker = false);
    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isWorkerValid = await _validateWorker();
    if (!isWorkerValid) return;

    setState(() => _isLoading = true);

    final data = {
      'id': widget.user?['id'],
      'nama': _namaCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'password': _passCtrl.text.trim(),
      'role': _role,
      'fungsi': _isOfficerSafety ? 'hsse' : _fungsi,
      'id_pekerja': _idPekerjaCtrl.text.trim(),
    };

    await widget.onSubmit(data);

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9, // Maksimal 90% tinggi layar
      ),
      decoration: BoxDecoration(
        color: UserHelpers.surfaceWhite,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔥 Header Fixed (tidak ikut scroll)
          _buildFixedHeader(),

          // 🔥 Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: bottomPadding + 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ID Pekerja (opsional untuk semua role)
                    _buildCompactSection(
                      icon: Icons.badge_rounded,
                      title: 'ID Pekerja',
                      subtitle: 'Hubungkan dengan data master (opsional)',
                      child: _buildIdPekerjaField(),
                    ),
                    const SizedBox(height: 16),

                    // Informasi Dasar
                    _buildCompactSection(
                      icon: Icons.person_rounded,
                      title: 'Informasi Dasar',
                      subtitle: 'Data identitas pengguna',
                      child: Column(
                        children: [
                          _buildCompactTextField(
                            controller: _namaCtrl,
                            label: 'Nama Lengkap',
                            hint: 'Masukkan nama lengkap',
                            icon: Icons.person_outline_rounded,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                              if (v.trim().length < 3) return 'Minimal 3 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildCompactTextField(
                            controller: _emailCtrl,
                            label: 'Alamat Email',
                            hint: 'contoh@email.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                              final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                              if (!regex.hasMatch(v.trim())) return 'Format tidak valid';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildCompactTextField(
                            controller: _phoneCtrl,
                            label: 'Nomor Telepon',
                            hint: '0812xxxxxx',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                              final trimmed = v.trim();
                              final digitOnly = RegExp(r'^[0-9]+$');
                              if (!digitOnly.hasMatch(trimmed)) return 'Hanya boleh angka';
                              if (trimmed.length < 10 || trimmed.length > 13) return '10-13 digit';
                              if (!trimmed.startsWith('0') && !trimmed.startsWith('62')) {
                                return 'Harus diawali 0 atau 62';
                              }
                              return null;
                            },
                          ),
                          if (!isEdit) ...[
                            const SizedBox(height: 12),
                            _buildCompactTextField(
                              controller: _passCtrl,
                              label: 'Password',
                              hint: 'Minimal 6 karakter',
                              icon: Icons.lock_outlined,
                              obscure: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Wajib diisi';
                                if (v.length < 6) return 'Minimal 6 karakter';
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role & Fungsi
                    _buildCompactSection(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Role & Departemen',
                      subtitle: isEdit ? 'Fungsi & departemen dikunci saat edit' : 'Hak akses pengguna',
                      child: Column(
                        children: [
                          // 🔒 Role dikunci saat edit
                          _buildCompactDropdown(
                            label: 'Role Pengguna',
                            value: _role,
                            icon: Icons.shield_outlined,
                            items: UserHelpers.roleList,
                            labels: UserHelpers.roleLabelList,
                            enabled: !isEdit, // Disabled saat edit
                            onChanged: (v) {
                              setState(() {
                                _role = v;
                                _isOfficerSafety = v == 'officer_safety';
                                if (_isOfficerSafety) _fungsi = 'hsse';
                              });
                            },
                          ),
                          if (!_isOfficerSafety) ...[
                            const SizedBox(height: 12),
                            // 🔒 Departemen dikunci saat edit
                            _buildCompactDropdown(
                              label: 'Departemen',
                              value: _fungsi,
                              icon: Icons.business_outlined,
                              items: UserHelpers.fungsiList,
                              labels: UserHelpers.fungsiLabelList,
                              enabled: !isEdit, // Disabled saat edit
                              onChanged: (v) => setState(() => _fungsi = v),
                            ),
                          ],
                          // 🚨 Catatan saat mode edit
                          if (isEdit) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1), // Kuning muda
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFFB300).withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: const Color(0xFFF57F17),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Edit data untuk fungsi & departemen hanya bisa diubah di menu Master Worker.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFFE65100),
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Info HSSE untuk Officer Safety
                          if (_isOfficerSafety) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: UserHelpers.accentDeepPurple.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: UserHelpers.accentDeepPurple.withOpacity(0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: UserHelpers.accentDeepPurple,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Otomatis menggunakan fungsi HSSE',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: UserHelpers.accentDeepPurple,
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
                    const SizedBox(height: 24),

                    // Submit Button
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FIXED HEADER ====================
  Widget _buildFixedHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: UserHelpers.dividerColor.withOpacity(0.5),
          ),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: UserHelpers.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header dengan icon dan title
          Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      UserHelpers.headerBlue,
                      UserHelpers.primaryLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: UserHelpers.headerBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Edit Pengguna' : 'Tambah Pengguna',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: UserHelpers.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEdit ? 'Perbarui data pengguna' : 'Lengkapi form di bawah ini',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: UserHelpers.textHint,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: UserHelpers.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== COMPACT SECTION ====================
  Widget _buildCompactSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UserHelpers.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UserHelpers.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: UserHelpers.headerBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: UserHelpers.headerBlue),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: UserHelpers.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: UserHelpers.textHint,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ==================== COMPACT TEXT FIELD ====================
  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: UserHelpers.textPrimary,
        height: 1.3,
      ),
      cursorColor: UserHelpers.headerBlue,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: UserHelpers.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: UserHelpers.textHint.withOpacity(0.6),
        ),
        prefixIcon: Icon(icon, size: 18, color: UserHelpers.headerBlue.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: UserHelpers.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: UserHelpers.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: UserHelpers.headerBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: UserHelpers.accentRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: UserHelpers.accentRed, width: 1.5),
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 11,
          color: UserHelpers.accentRed,
          height: 1.2,
        ),
      ),
    );
  }

  // ==================== COMPACT DROPDOWN ====================
  Widget _buildCompactDropdown({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String> onChanged,
    bool enabled = true, // 🔥 PARAMETER BARU: untuk mengunci dropdown
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.white,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: enabled ? UserHelpers.textPrimary : UserHelpers.textHint,
        height: 1.3,
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: enabled ? UserHelpers.textSecondary : UserHelpers.dividerColor,
        size: 20,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: enabled ? UserHelpers.textSecondary : UserHelpers.textHint,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: enabled
              ? UserHelpers.headerBlue.withOpacity(0.6)
              : UserHelpers.textHint.withOpacity(0.5),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : UserHelpers.dividerColor.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: enabled ? UserHelpers.dividerColor : UserHelpers.dividerColor.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: enabled ? UserHelpers.dividerColor : UserHelpers.dividerColor.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: enabled ? UserHelpers.headerBlue : UserHelpers.dividerColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
      ),
      items: items.asMap().entries.map((e) {
        return DropdownMenuItem(
          value: e.value,
          child: Text(
            labels[e.key],
            style: GoogleFonts.inter(fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: enabled
          ? (v) {
              if (v != null) onChanged(v);
            }
          : null, // Disabled jika enabled = false
    );
  }

  // ==================== ID PEKERJA FIELD (COMPACT) ====================
  Widget _buildIdPekerjaField() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _idPekerjaCtrl,
            focusNode: _idPekerjaFocus,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: UserHelpers.textPrimary,
              height: 1.3,
            ),
            cursorColor: UserHelpers.headerBlue,
            decoration: InputDecoration(
              labelText: 'ID Pekerja',
              hintText: 'Ketik ID atau nama pekerja...',
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                color: UserHelpers.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: UserHelpers.textHint.withOpacity(0.6),
              ),
              prefixIcon: Icon(
                Icons.badge_outlined,
                size: 18,
                color: _selectedWorker != null
                    ? const Color(0xFF10B981)
                    : UserHelpers.headerBlue.withOpacity(0.6),
              ),
              suffixIcon: _isValidatingWorker
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _selectedWorker != null
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                        )
                      : _idPekerjaCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, size: 16, color: UserHelpers.textHint),
                              onPressed: () {
                                _idPekerjaCtrl.clear();
                                setState(() {
                                  _selectedWorker = null;
                                  _workerValidationError = null;
                                  _showWorkerDropdown = false;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            )
                          : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _workerValidationError != null
                      ? UserHelpers.accentRed
                      : UserHelpers.dividerColor,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _workerValidationError != null
                      ? UserHelpers.accentRed
                      : UserHelpers.dividerColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _workerValidationError != null
                      ? UserHelpers.accentRed
                      : UserHelpers.headerBlue,
                  width: 1.5,
                ),
              ),
            ),
            // onChanged dihapus -> cukup addListener di initState (menghindari trigger dobel)
            onTap: () {
              if (_idPekerjaCtrl.text.isNotEmpty) {
                setState(() => _showWorkerDropdown = true);
              }
            },
          ),

          // Error message
          if (_workerValidationError != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 4),
                Icon(Icons.error_outline_rounded, size: 14, color: UserHelpers.accentRed),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _workerValidationError!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: UserHelpers.accentRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Selected worker compact card
          if (_selectedWorker != null) ...[
            const SizedBox(height: 8),
            _buildCompactWorkerCard(_selectedWorker!),
          ],

          // Dropdown suggestions
          if (_showWorkerDropdown && _filteredWorkers.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildCompactWorkerDropdown(),
          ],
        ],
      ),
    );
  }

  // Compact worker info card
  Widget _buildCompactWorkerCard(Map<String, dynamic> worker) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                (worker['nama']?.toString() ?? '?')[0].toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker['nama'] ?? '-',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: UserHelpers.textPrimary,
                  ),
                ),
                Text(
                  '${worker['fungsi'] ?? '-'} • ${worker['role'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: UserHelpers.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded, color: const Color(0xFF10B981), size: 18),
        ],
      ),
    );
  }

  // Compact worker dropdown
  Widget _buildCompactWorkerDropdown() {
    return CompositedTransformFollower(
      link: _layerLink,
      offset: const Offset(0, 55),
      showWhenUnlinked: false,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          shrinkWrap: true,
          itemCount: _filteredWorkers.length.clamp(0, 6),
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 12, endIndent: 12),
          itemBuilder: (_, i) {
            final worker = _filteredWorkers[i];
            return InkWell(
              onTap: () => _selectWorker(worker),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: UserHelpers.headerBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          (worker['nama']?.toString() ?? '?')[0].toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: UserHelpers.headerBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker['id_pekerja'] ?? '-',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: UserHelpers.textPrimary,
                            ),
                          ),
                          Text(
                            worker['nama'] ?? '-',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: UserHelpers.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        worker['fungsi'] ?? '-',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: UserHelpers.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==================== SUBMIT BUTTON ====================
  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: _isLoading
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [UserHelpers.headerBlue, UserHelpers.primaryLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isLoading ? Colors.grey : UserHelpers.headerBlue).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Menyimpan...',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEdit ? Icons.save_rounded : Icons.person_add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Simpan Perubahan' : 'Tambah Pengguna',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}