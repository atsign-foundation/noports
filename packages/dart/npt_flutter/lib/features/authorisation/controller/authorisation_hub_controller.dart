import 'dart:async';

import 'package:at_auth/at_auth.dart'
    show AtEnrollment, EnrollmentRequestDecision, Otp, ServerEnrollmentRequest;
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:npt_flutter/features/authorisation/models/authorisation_page_section.dart';

class AuthorisationHubController extends ChangeNotifier {
  AuthorisationHubController({FlutterEnrollmentService? service})
    : _service = service ?? FlutterEnrollmentService();

  final FlutterEnrollmentService _service;
  final AtEnrollment _atEnrollment = AtEnrollment.create();

  AuthorisationPageSection _section = AuthorisationPageSection.requests;

  bool _isManagerKey = true;
  bool _managerKeyChecked = false;
  String? _managerKeyError;

  Otp? _otp;
  bool _otpLoading = false;
  String? _otpError;

  SppData? _spp;
  bool _sppSaving = false;
  String? _sppFetchError;
  String? _sppSaveError;

  List<ServerEnrollmentRequest> _pending = const <ServerEnrollmentRequest>[];
  bool _pendingLoading = false;
  String? _pendingError;
  StreamSubscription<ServerEnrollmentRequest>? _pendingSubscription;

  List<ServerEnrollmentRequest> _approved = const <ServerEnrollmentRequest>[];
  bool _approvedLoading = false;
  String? _approvedError;

  bool _disposed = false;

  AuthorisationPageSection get section => _section;

  bool get isManagerKey => _isManagerKey;
  bool get managerKeyChecked => _managerKeyChecked;
  String? get managerKeyError => _managerKeyError;

  Otp? get otp => _otp;
  bool get otpLoading => _otpLoading;
  String? get otpError => _otpError;

  SppData? get spp => _spp;
  bool get sppSaving => _sppSaving;
  String? get sppFetchError => _sppFetchError;
  String? get sppSaveError => _sppSaveError;

  List<ServerEnrollmentRequest> get pending => _pending;
  bool get pendingLoading => _pendingLoading;
  String? get pendingError => _pendingError;

  List<ServerEnrollmentRequest> get approved => _approved;
  bool get approvedLoading => _approvedLoading;
  String? get approvedError => _approvedError;

  String get _atSign =>
      AtClientManager.getInstance().atClient.getCurrentAtSign()!;

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void selectSection(AuthorisationPageSection section) {
    if (_section == section) return;
    _section = section;
    _notify();
    switch (section) {
      case AuthorisationPageSection.requests:
        unawaited(loadPendingRequests());
      case AuthorisationPageSection.approvedEnrollments:
        unawaited(loadApprovedEnrollments());
      case AuthorisationPageSection.otp:
      case AuthorisationPageSection.setPin:
        break;
    }
  }

  Future<void> init() async {
    _subscribeToNewRequests();
    await Future.wait(<Future<void>>[
      checkManagerKey(),
      generateOtp(),
      loadSpp(),
      loadPendingRequests(),
      loadApprovedEnrollments(),
    ]);
  }

  void _subscribeToNewRequests() {
    _pendingSubscription ??= _service
        .getEnrollments(statusFilters: <EnrollmentStatus>[
          EnrollmentStatus.pending,
        ])
        .listen((ServerEnrollmentRequest request) {
          if (_pending.any(
            (ServerEnrollmentRequest r) =>
                r.enrollmentId == request.enrollmentId,
          )) {
            return;
          }
          _pending = <ServerEnrollmentRequest>[..._pending, request];
          _notify();
        }, onError: (Object e) => unawaited(loadPendingRequests()));
  }

  Future<void> checkManagerKey() async {
    try {
      _isManagerKey = await _service.isManagerKey();
      _managerKeyError = null;
    } catch (e) {
      _isManagerKey = true;
      _managerKeyError = e.toString();
    } finally {
      _managerKeyChecked = true;
      _notify();
    }
  }

  Future<void> generateOtp({bool refresh = false}) async {
    if (_otpLoading) return;
    if (_otp != null && !refresh && !_otp!.isExpired) return;

    _otpLoading = true;
    if (refresh) {
      _otp = null;
      _otpError = null;
    }
    _notify();

    try {
      _otp = await _service.generateOtp();
      _otpError = null;
    } catch (e) {
      _otp = null;
      _otpError = e.toString();
    } finally {
      _otpLoading = false;
      _notify();
    }
  }

  Future<void> loadSpp() async {
    try {
      _spp = await _service.getActiveSpp();
      _sppFetchError = null;
    } catch (e) {
      _spp = null;
      _sppFetchError = e.toString();
    } finally {
      _notify();
    }
  }

  Future<void> setSpp(String value, Duration expiry) async {
    _sppSaving = true;
    _sppSaveError = null;
    _notify();

    try {
      final Otp saved = await _service.setSpp(spp: value, sppExpiry: expiry);
      _spp = SppData(value: saved.value, expiry: saved.expiry);
      _otp = saved;
      _otpError = null;
    } catch (e) {
      _sppSaveError = e.toString();
    } finally {
      _sppSaving = false;
      _notify();
    }
  }

  Future<void> loadPendingRequests() async {
    _pendingLoading = true;
    _notify();

    try {
      _pending = await _service.list(<EnrollmentStatus>[
        EnrollmentStatus.pending,
      ], AtClientManager.getInstance().atClient.getRemoteSecondary()!.atLookUp);
      _pendingError = null;
    } catch (e) {
      _pending = const <ServerEnrollmentRequest>[];
      _pendingError = e.toString();
    } finally {
      _pendingLoading = false;
      _notify();
    }
  }

  Future<void> loadApprovedEnrollments() async {
    _approvedLoading = true;
    _notify();

    try {
      _approved = await _service.list(<EnrollmentStatus>[
        EnrollmentStatus.approved,
      ], AtClientManager.getInstance().atClient.getRemoteSecondary()!.atLookUp);
      _approvedError = null;
    } catch (e) {
      _approved = const <ServerEnrollmentRequest>[];
      _approvedError = e.toString();
    } finally {
      _approvedLoading = false;
      _notify();
    }
  }

  Future<String?> approveRequest(ServerEnrollmentRequest request) async {
    final String? symmetricKey = request.encryptedAPKAMSymmetricKey;
    if (symmetricKey == null || symmetricKey.isEmpty) {
      return 'This request is missing its encrypted APKAM symmetric key and cannot be approved.';
    }

    try {
      await _atEnrollment.approve(
        EnrollmentRequestDecision.approved(
          enrollmentId: request.enrollmentId,
          apkamSymmetricKey: AtBytes.fromString(symmetricKey),
          atSign: _atSign,
        ),
        AtClientManager.getInstance().atClient.getRemoteSecondary()!.atLookUp,
      );
      _removePending(request);
      return null;
    } catch (e) {
      return _decisionError(e, 'approve');
    }
  }

  Future<String?> denyRequest(ServerEnrollmentRequest request) async {
    try {
      await _atEnrollment.deny(
        EnrollmentRequestDecision.denied(request.enrollmentId, _atSign),
        AtClientManager.getInstance().atClient.getRemoteSecondary()!.atLookUp,
      );
      _removePending(request);
      return null;
    } catch (e) {
      return _decisionError(e, 'deny');
    }
  }

  Future<String?> revokeRequest(ServerEnrollmentRequest request) async {
    try {
      await _atEnrollment.revoke(
        EnrollmentRequestDecision.revoked(request.enrollmentId, _atSign),
        AtClientManager.getInstance().atClient.getRemoteSecondary()!.atLookUp,
      );
      _approved = _approved
          .where(
            (ServerEnrollmentRequest r) =>
                r.enrollmentId != request.enrollmentId,
          )
          .toList();
      _notify();
      return null;
    } catch (e) {
      return _decisionError(e, 'revoke');
    }
  }

  void _removePending(ServerEnrollmentRequest request) {
    _pending = _pending
        .where(
          (ServerEnrollmentRequest r) =>
              r.enrollmentId != request.enrollmentId,
        )
        .toList();
    _notify();
  }

  String _decisionError(Object error, String action) {
    final String message = error.toString();
    if (message.contains('authorized') || message.contains('manage')) {
      return 'These keys are not authorised to $action enrollments for $_atSign.';
    }
    return 'Failed to $action: $message';
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_pendingSubscription?.cancel());
    unawaited(_service.dispose());
    super.dispose();
  }
}
