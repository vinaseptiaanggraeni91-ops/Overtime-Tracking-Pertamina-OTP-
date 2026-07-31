// lib/widgets/ajukan_lembur/progress_stepper.dart
import 'package:flutter/material.dart';

class ProgressStepper extends StatelessWidget {
  final double completionPercentage;
  final bool hasMitra;
  final bool hasTanggal;
  final bool hasWaktu;
  final bool hasLokasi;
  final bool hasAlasan;
  final bool isMultiDay;       // 🔥 BARU
  final bool isOvernight;      // 🔥 BARU

  const ProgressStepper({
    super.key,
    required this.completionPercentage,
    this.hasMitra = false,
    this.hasTanggal = false,
    this.hasWaktu = false,
    this.hasLokasi = false,
    this.hasAlasan = false,
    this.isMultiDay = false,   // 🔥 BARU
    this.isOvernight = false,  // 🔥 BARU
  });

  int get _currentStep {
    if (hasAlasan && hasLokasi && hasWaktu && hasTanggal && hasMitra) return 4;
    if (hasLokasi && hasWaktu && hasTanggal && hasMitra) return 3;
    if (hasWaktu && hasTanggal && hasMitra) return 2;
    if (hasTanggal && hasMitra) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    final steps = [
      _StepData(icon: Icons.people_alt_rounded, label: "Mitra"),
      _StepData(
        icon: isMultiDay 
            ? Icons.date_range_rounded      // 🔥 Icon berubah untuk multi-hari
            : Icons.access_time_rounded, 
        label: "Waktu",
        hasSpecial: isMultiDay || isOvernight,  // 🔥 Flag special
      ),
      _StepData(icon: Icons.location_on_rounded, label: "Lokasi"),
      _StepData(icon: Icons.description_rounded, label: "Alasan"),
      _StepData(icon: Icons.check_circle_rounded, label: "Selesai"),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 12 : 16, 
        horizontal: isSmallScreen ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🔥 STEP CIRCLES
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                _buildStepCircle(
                  icon: steps[i].icon,
                  label: steps[i].label,
                  isActive: _currentStep > i,
                  isCurrent: _currentStep == i,
                  stepNumber: i + 1,
                  hasSpecial: steps[i].hasSpecial,
                  isSmallScreen: isSmallScreen,
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 2 : 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: _currentStep > i
                            ? const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)])
                            : LinearGradient(
                                colors: [
                                  Colors.grey.shade200,
                                  Colors.grey.shade300
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          
          // 🔥 SPECIAL INDICATOR (Multi-Day / Overnight)
          if (isMultiDay || isOvernight) ...[
            SizedBox(height: isSmallScreen ? 8 : 10),
            _buildSpecialIndicator(isSmallScreen),
          ],
          
          SizedBox(height: isSmallScreen ? 8 : 12),
          
          // 🔥 PROGRESS BAR
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completionPercentage,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isMultiDay || isOvernight 
                    ? Colors.purple           // 🔥 Warna ungu untuk special
                    : const Color(0xFF4CAF50)
              ),
              minHeight: isSmallScreen ? 5 : 6,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          
          // 🔥 PERCENTAGE TEXT
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${(completionPercentage * 100).toInt()}% Lengkap",
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: completionPercentage > 0.5
                      ? (isMultiDay || isOvernight 
                          ? Colors.purple 
                          : const Color(0xFF4CAF50))
                      : Colors.grey.shade500,
                ),
              ),
              // 🔥 Badge kecil untuk multi-day/overnight
              if (isMultiDay || isOvernight) ...[
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8, 
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade200, width: 0.5),
                  ),
                  child: Text(
                    isMultiDay ? 'Multi' : 'Malam',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 8 : 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.purple.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==================== STEP CIRCLE ====================
  Widget _buildStepCircle({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCurrent,
    required int stepNumber,
    bool hasSpecial = false,
    bool isSmallScreen = false,
  }) {
    final double circleSize = isSmallScreen ? 34 : 40;
    final double iconSize = isSmallScreen ? 16 : 20;
    
    // 🔥 Warna untuk step dengan special flag
    final Color activeColor = hasSpecial ? Colors.purple : const Color(0xFF4CAF50);
    final Color currentColor = hasSpecial ? Colors.purple.shade700 : const Color(0xFF1976D2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive
                ? LinearGradient(
                    colors: [activeColor, activeColor.withValues(alpha: 0.8)],
                  )
                : isCurrent
                    ? LinearGradient(
                        colors: [currentColor, currentColor.withValues(alpha: 0.8)],
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade200, Colors.grey.shade300],
                      ),
            boxShadow: isActive || isCurrent
                ? [
                    BoxShadow(
                      color: (isActive ? activeColor : currentColor)
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
            // 🔥 Border untuk special step
            border: hasSpecial && !isActive && !isCurrent
                ? Border.all(color: Colors.purple.shade200, width: 1.5)
                : null,
          ),
          child: Center(
            child: isActive
                ? Icon(Icons.check, size: iconSize, color: Colors.white)
                : isCurrent
                    ? Icon(icon, size: iconSize, color: Colors.white)
                    : Text(
                        stepNumber.toString(),
                        style: TextStyle(
                          color: hasSpecial 
                              ? Colors.purple.shade400 
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 3 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 8 : 10,
            fontWeight: isActive || isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? activeColor
                : isCurrent
                    ? currentColor
                    : hasSpecial 
                        ? Colors.purple.shade400 
                        : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // 🔥 SPECIAL INDICATOR (Multi-Day / Overnight)
  Widget _buildSpecialIndicator(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 10 : 14, 
        vertical: isSmallScreen ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade50,
            Colors.purple.shade100.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMultiDay ? Icons.date_range_rounded : Icons.nights_stay_rounded,
            size: isSmallScreen ? 14 : 16,
            color: Colors.purple.shade600,
          ),
          SizedBox(width: isSmallScreen ? 6 : 8),
          Flexible(
            child: Text(
              isMultiDay 
                  ? 'Lembur Multi-Hari — Dipecah per tanggal' 
                  : 'Lembur Lintas Malam — Melewati tengah malam',
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: Colors.purple.shade700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String label;
  final bool hasSpecial;  // 🔥 BARU
  
  const _StepData({
    required this.icon, 
    required this.label,
    this.hasSpecial = false,
  });
}