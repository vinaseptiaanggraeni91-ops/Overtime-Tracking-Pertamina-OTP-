// lib/features/superadmin/widgets/user_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/user_helpers.dart';

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool canEdit;
  final bool canDelete;
  final bool isCurrentUser;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const UserCard({
    super.key,
    required this.user,
    required this.canEdit,
    required this.canDelete,
    required this.isCurrentUser,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final role = user['role'] ?? 'mitra';
    final status = user['status_akun'] ?? 'active';
    final nama = user['nama_lengkap'] ?? '-';
    final email = user['email'] ?? '-';
    final fungsi = user['fungsi'] ?? '-';
    final phone = user['phone'] ?? '';
    final roleColor = UserHelpers.roleColor(role);
    final statusColor = UserHelpers.statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: UserHelpers.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: UserHelpers.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: UserHelpers.headerBlue.withOpacity(0.05),
          highlightColor: UserHelpers.headerBlue.withOpacity(0.03),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildTopRow(role, nama, email, status, roleColor, statusColor),
                const SizedBox(height: 14),
                _buildMiddleRow(role, fungsi, phone, roleColor),
                const SizedBox(height: 14),
                _buildBottomRow(status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(String role, String nama, String email, String status, Color roleColor, Color statusColor) {
    return Row(
      children: [
        // Avatar
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [roleColor.withOpacity(0.2), roleColor.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: roleColor.withOpacity(0.3), width: 1.5),
          ),
          child: Icon(UserHelpers.roleIcon(role), color: roleColor, size: 26),
        ),
        const SizedBox(width: 14),
        // Nama & Email
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nama,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: UserHelpers.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: GoogleFonts.inter(fontSize: 12, color: UserHelpers.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: statusColor, blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                UserHelpers.statusLabel(status),
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ PERBAIKAN: Middle row dengan Wrap untuk menghindari overflow
  Widget _buildMiddleRow(String role, String fungsi, String phone, Color roleColor) {
    return Row(
      children: [
        // Info chips dibungkus Flexible agar tidak overflow
        Flexible(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _InfoChip(
                icon: Icons.shield_rounded,
                text: UserHelpers.roleLabel(role),
                color: roleColor,
              ),
              _InfoChip(
                icon: Icons.business_rounded,
                text: UserHelpers.fungsiLabel(fungsi),
                color: UserHelpers.fungsiColor(fungsi),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Phone number dengan Flexible dan overflow ellipsis
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_rounded, size: 14, color: UserHelpers.textLight),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  phone.isNotEmpty && phone.length >= 8
                      ? '${phone.substring(0, 4)}...${phone.substring(phone.length - 4)}'
                      : phone,
                  style: GoogleFonts.inter(fontSize: 11, color: UserHelpers.textLight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomRow(String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            '🕐 ${UserHelpers.formatDate(user['created_at'])}',
            style: GoogleFonts.inter(fontSize: 11, color: UserHelpers.textLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Action buttons dibungkus Wrap untuk mengantisipasi banyak tombol
        Flexible(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              if (canEdit && !isCurrentUser)
                _ActionButton(
                  icon: Icons.edit_rounded,
                  color: UserHelpers.headerBlue,
                  onTap: onEdit,
                ),
              if (!isCurrentUser)
                _ActionButton(
                  icon: status == 'active' ? Icons.block_rounded : Icons.check_circle_rounded,
                  color: status == 'active' ? UserHelpers.accentOrange : UserHelpers.accentGreen,
                  onTap: onToggleStatus,
                ),
              if (canDelete && !isCurrentUser)
                _ActionButton(
                  icon: Icons.delete_rounded,
                  color: UserHelpers.accentRed,
                  onTap: onDelete,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}