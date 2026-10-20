import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:npt_flutter/features/authorisation/models/authorisation_page_section.dart';

class AuthorisationHubController extends ChangeNotifier {
  AuthorisationHubController({AtClient? client, KeychainStorage? keychain})
    : _client = client,
      _keychain = keychain ?? KeychainStorage();

  final AtClient? _client;
  final KeychainStorage _keychain;

  AuthorisationPageSection _section = AuthorisationPageSection.requests;

  bool _isManagerKey = true;
  bool _managerKeyChecked = false;
  String? _managerKeyError;

  Passcode? _otp;
  bool _otpLoading = false;
  String? _otpError;

  SppData? _spp;
  bool _sppSaving = false;
  String? _sppFetchError;
  String? _sppSaveError;

  List<Enrollment> _pending = const <Enrollment>[];
  bool _pendingLoading = false;
  String? _pendingError;
  StreamSubscription<Enrollment>? _pendingSubscription;

  List<Enrollment> _approved = const <Enrollment>[];
  bool _approvedLoading = false;
  String? _approvedError;

  bool _disposed = false;

  AuthorisationPageSection get section => _section;

  bool get isManagerKey => _isManagerKey;
  bool get managerKeyChecked => _managerKeyChecked;
  String? get managerKeyError => _managerKeyError;

  Passcode? get otp => _otp;
  bool get otpLoading => _otpLoading;
  String? get otpError => _otpError;

  SppData? get spp => _spp;
  bool get sppSaving => _sppSaving;
  String? get sppFetchError => _sppFetchError;
  String? get sppSaveError => _sppSaveError;

  List<Enrollment> get pending => _pending;
  bool get pendingLoading => _pendingLoading;
  String? get pendingError => _pendingError;

  List<Enrollment> get approved => _approved;
  bool get approvedLoading => _approvedLoading;
  String? get approvedError => _approvedError;

  AtClient get client => _client ?? AtClientManager.getInstance().atClient;

  Enrollments get _enrollments => client.enrollments;

  String get _atSign => client.getCurrentAtSign()!;

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
    _pendingSubscription ??= _enrollments.requests.listen((
      Enrollment request,
    ) {
      if (_pending.any(
        (Enrollment r) => r.enrollmentId == request.enrollmentId,
      )) {
        return;
      }
      _pending = <Enrollment>[..._pending, request];
      _notify();
    }, onError: (Object e) => unawaited(loadPendingRequests()));
  }

  /// Whether the keys this client authenticates with may decide enrollments:
  /// the roster can be read at all, and an approved enrollment on it holds
  /// `__manage`.
  Future<void> checkManagerKey() async {
    try {
      final List<Enrollment> enrollments = await _enrollments.list();
      _isManagerKey = enrollments.any(
        (Enrollment e) =>
            e.status == EnrollmentStatus.approved.name &&
            e.namespace?['__manage'] == 'rw',
      );
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
      _otp = await _enrollments.otp();
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
      _spp = await _keychain.getActiveSpp(_atSign);
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
      final Passcode saved = await _enrollments.spp(value, expiry: expiry);
      await _keychain.saveSpp(_atSign, saved);
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
      _pending = await _enrollments.pending();
      _pendingError = null;
    } catch (e) {
      _pending = const <Enrollment>[];
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
      _approved = await _enrollments.list(
        statuses: <EnrollmentStatus>[EnrollmentStatus.approved],
      );
      _approvedError = null;
    } catch (e) {
      _approved = const <Enrollment>[];
      _approvedError = e.toString();
    } finally {
      _approvedLoading = false;
      _notify();
    }
  }

  Future<String?> approveRequest(Enrollment request) async {
    try {
      await _enrollments.approve(request.enrollmentId!);
      _removePending(request);
      return null;
    } catch (e) {
      return _decisionError(e, 'approve');
    }
  }

  Future<String?> denyRequest(Enrollment request) async {
    try {
      await _enrollments.deny(request.enrollmentId!);
      _removePending(request);
      return null;
    } catch (e) {
      return _decisionError(e, 'deny');
    }
  }

  Future<String?> revokeRequest(Enrollment request) async {
    try {
      await _enrollments.revoke(request.enrollmentId!);
      _approved = _approved
          .where((Enrollment r) => r.enrollmentId != request.enrollmentId)
          .toList();
      _notify();
      return null;
    } catch (e) {
      return _decisionError(e, 'revoke');
    }
  }

  void _removePending(Enrollment request) {
    _pending = _pending
        .where((Enrollment r) => r.enrollmentId != request.enrollmentId)
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
    super.dispose();
  }
}
