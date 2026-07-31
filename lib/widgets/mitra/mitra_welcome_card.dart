// lib/widgets/mitra/mitra_welcome_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MitraWelcomeCard extends StatelessWidget {
  final String greeting;
  final String motivation;
  final String userName;
  final String userRole;
  final String? userPhotoUrl;
  final String formattedDate;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;

  const MitraWelcomeCard({
    super.key,
    required this.greeting,
    required this.motivation,
    required this.userName,
    required this.userRole,
    this.userPhotoUrl,
    required this.formattedDate,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onNotificationsTap,
    required this.onProfileTap,
  });

  // ═══════════════════════════════════════════════════════
  // 🔵 PREMIUM COLOR PALETTE
  // ═══════════════════════════════════════════════════════
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color accentGold = Color(0xFFFFAB40);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final sf = (screenWidth / 400).clamp(0.88, 1.1);
    final currentTime = DateFormat('HH:mm').format(DateTime.now());

    return Container(
      // ✅ PADDING DIPERBESAR: 18 → 24 (card lebih tinggi)
      padding: EdgeInsets.all(24 * sf),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryDark, primaryColor, Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 14),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border.all(
          color: surfaceWhite.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          // Decorative glow top right
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    surfaceWhite.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Decorative glow bottom left
          Positioned(
            bottom: -30,
            left: -25,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentGold.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Decorative dot kecil
          Positioned(
            top: 20 * sf,
            right: 20 * sf,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: surfaceWhite.withValues(alpha: 0.3),
              ),
            ),
          ),

          // Main Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══════════════════════════════════════
              // ROW 1: Avatar + Greeting + Actions
              // ═══════════════════════════════════════
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photo - lebih besar
                  GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 58 * sf, // ✅ 52 → 58
                      height: 58 * sf, // ✅ 52 → 58
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentGold,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentGold.withValues(alpha: 0.5),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 26 * sf,
                        backgroundColor: surfaceWhite.withValues(alpha: 0.15),
                        backgroundImage: userPhotoUrl != null &&
                                userPhotoUrl!.isNotEmpty
                            ? NetworkImage(userPhotoUrl!)
                            : null,
                        child: userPhotoUrl == null || userPhotoUrl!.isEmpty
                            ? Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'M',
                                style: TextStyle(
                                  fontSize: 22 * sf,
                                  fontWeight: FontWeight.w800,
                                  color: surfaceWhite,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(width: 16 * sf), // ✅ 14 → 16

                  // Greeting & Motivation
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            fontSize: (isSmall ? 16 : 18) * sf, // ✅ 15-17 → 16-18
                            fontWeight: FontWeight.w800,
                            color: surfaceWhite,
                            height: 1.3,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6 * sf), // ✅ 4 → 6
                        Text(
                          motivation,
                          style: TextStyle(
                            fontSize: (isSmall ? 11 : 12) * sf, // ✅ 10-11 → 11-12
                            color: accentGold.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10 * sf), // ✅ 8 → 10

                  // Action Buttons - lebih besar
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Refresh Button
                      isRefreshing
                          ? SizedBox(
                              width: 40 * sf, // ✅ 36 → 40
                              height: 40 * sf,
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: accentGold,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: onRefresh,
                              child: Container(
                                width: 40 * sf, // ✅ 36 → 40
                                height: 40 * sf,
                                decoration: BoxDecoration(
                                  color: surfaceWhite.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: surfaceWhite.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  color: surfaceWhite,
                                  size: 20 * sf, // ✅ 18 → 20
                                ),
                              ),
                            ),
                      SizedBox(height: 10 * sf), // ✅ 8 → 10
                      // Notification Button
                      GestureDetector(
                        onTap: onNotificationsTap,
                        child: Container(
                          width: 40 * sf, // ✅ 36 → 40
                          height: 40 * sf,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentGold,
                                accentGold.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accentGold.withValues(alpha: 0.5),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.notifications_rounded,
                            color: primaryDark,
                            size: 20 * sf, // ✅ 18 → 20
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 22 * sf), // ✅ 16 → 22

              // ═══════════════════════════════════════
              // STATUS BAR - TANPA PAGI/MALAM
              // ═══════════════════════════════════════
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * sf, // ✅ 14 → 16
                  vertical: 14 * sf, // ✅ 12 → 14
                ),
                decoration: BoxDecoration(
                  color: surfaceWhite.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: surfaceWhite.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Role Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * sf, // ✅ 10 → 12
                        vertical: 8 * sf, // ✅ 6 → 8
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentGold.withValues(alpha: 0.35),
                            accentGold.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentGold.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 16 * sf, // ✅ 14 → 16
                            color: accentGold,
                          ),
                          SizedBox(width: 6),
                          Text(
                            userRole.isNotEmpty
                                ? userRole.toUpperCase()
                                : 'MITRA',
                            style: TextStyle(
                              fontSize: (isSmall ? 11 : 12) * sf, // ✅ 10-11 → 11-12
                              fontWeight: FontWeight.w700,
                              color: accentGold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 12 * sf), // ✅ 10 → 12

                    // Divider
                    Container(
                      width: 1.5,
                      height: 26 * sf, // ✅ 22 → 26
                      color: surfaceWhite.withValues(alpha: 0.3),
                    ),

                    SizedBox(width: 12 * sf), // ✅ 10 → 12

                    // Date
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 15 * sf, // ✅ 13 → 15
                          color: surfaceWhite.withValues(alpha: 0.85),
                        ),
                        SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: (isSmall ? 11 : 12) * sf, // ✅ 10-11 → 11-12
                            fontWeight: FontWeight.w500,
                            color: surfaceWhite.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // ✅ JAM SAJA (TANPA PAGI/SIANG/SORE/MALAM)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 15 * sf,
                          color: surfaceWhite.withValues(alpha: 0.85),
                        ),
                        SizedBox(width: 6),
                        Text(
                          currentTime,
                          style: TextStyle(
                            fontSize: (isSmall ? 12 : 13) * sf,
                            fontWeight: FontWeight.w700,
                            color: surfaceWhite,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'WIB',
                          style: TextStyle(
                            fontSize: (isSmall ? 9 : 10) * sf,
                            fontWeight: FontWeight.w500,
                            color: surfaceWhite.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}