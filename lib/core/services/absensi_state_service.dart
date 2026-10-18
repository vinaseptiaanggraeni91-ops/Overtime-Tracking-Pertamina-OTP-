// lib/core/services/absensi_state_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

enum AbsensiFlow {
  idle,
  loading,
  error,
  noOvertime,
  upcomingOvertime,      // Belum waktunya
  normalAbsensi,         // Absensi normal (verifikasi lokasi)
  lateOvertimeWarning,   // Peringatan terlambat
  lateOvertimeForm,      // Form konfirmasi
  selfieReady,           // Siap ambil selfie
  submitting,            // Sedang submit
  checkedIn,             // Sudah check-in
  checkingOut,           // Sedang check-out
  checkedOut,            // Selesai
}

class AbsensiState {
  final AbsensiFlow flow;
  final String statusMessage;
  final String? errorDetail;
  final bool isLoading;
  final bool isSubmitting;
  final bool isCheckingOut;
  final bool locationValid;
  final bool locationVerified;
  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final bool canCheckOut;
  final bool canConfirm;
  final bool showKonfirmasiForm;
  final bool isLiveLocationActive;
  final String? liveLocationDuration;
  final bool isLateOvertime;
  final int currentTabIndex;
  final bool hasUpcomingOvertime;

  const AbsensiState({
    this.flow = AbsensiFlow.idle,
    this.statusMessage = '',
    this.errorDetail,
    this.isLoading = false,
    this.isSubmitting = false,
    this.isCheckingOut = false,
    this.locationValid = false,
    this.locationVerified = false,
    this.hasCheckedIn = false,
    this.hasCheckedOut = false,
    this.canCheckOut = false,
    this.canConfirm = false,
    this.showKonfirmasiForm = false,
    this.isLiveLocationActive = false,
    this.liveLocationDuration,
    this.isLateOvertime = false,
    this.currentTabIndex = 0,
    this.hasUpcomingOvertime = false,
  });

  AbsensiState copyWith({
    AbsensiFlow? flow,
    String? statusMessage,
    String? errorDetail,
    bool? isLoading,
    bool? isSubmitting,
    bool? isCheckingOut,
    bool? locationValid,
    bool? locationVerified,
    bool? hasCheckedIn,
    bool? hasCheckedOut,
    bool? canCheckOut,
    bool? canConfirm,
    bool? showKonfirmasiForm,
    bool? isLiveLocationActive,
    String? liveLocationDuration,
    bool? isLateOvertime,
    int? currentTabIndex,
    bool? hasUpcomingOvertime,
    bool clearError = false,
  }) {
    return AbsensiState(
      flow: flow ?? this.flow,
      statusMessage: statusMessage ?? this.statusMessage,
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      locationValid: locationValid ?? this.locationValid,
      locationVerified: locationVerified ?? this.locationVerified,
      hasCheckedIn: hasCheckedIn ?? this.hasCheckedIn,
      hasCheckedOut: hasCheckedOut ?? this.hasCheckedOut,
      canCheckOut: canCheckOut ?? this.canCheckOut,
      canConfirm: canConfirm ?? this.canConfirm,
      showKonfirmasiForm: showKonfirmasiForm ?? this.showKonfirmasiForm,
      isLiveLocationActive: isLiveLocationActive ?? this.isLiveLocationActive,
      liveLocationDuration: liveLocationDuration ?? this.liveLocationDuration,
      isLateOvertime: isLateOvertime ?? this.isLateOvertime,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      hasUpcomingOvertime: hasUpcomingOvertime ?? this.hasUpcomingOvertime,
    );
  }
}

class AbsensiStateService extends ChangeNotifier {
  AbsensiState _state = const AbsensiState();
  AbsensiState get state => _state;

  bool _isDisposed = false;

  void updateState(AbsensiState newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }

  void emit(AbsensiState Function(AbsensiState) builder) {
    if (_isDisposed) return;
    _state = builder(_state);
    notifyListeners();
  }

  void setLoading(String message) {
    emit((s) => s.copyWith(
      flow: AbsensiFlow.loading,
      isLoading: true,
      statusMessage: message,
      clearError: true,
    ));
  }

  void setError(String message, {String? detail}) {
    emit((s) => s.copyWith(
      flow: AbsensiFlow.error,
      isLoading: false,
      isSubmitting: false,
      isCheckingOut: false,
      statusMessage: message,
      errorDetail: detail,
    ));
  }

  void setIdle() {
    emit((s) => s.copyWith(
      flow: AbsensiFlow.idle,
      isLoading: false,
    ));
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}