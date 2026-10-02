import 'dart:async';

import 'package:at_auth/at_auth.dart' show ServerEnrollmentRequest;
import 'package:at_client_flutter/at_client_flutter.dart';

import '../../logging/models/loggable.dart';
import '../../logging/models/logging_bloc.dart';

class Count extends Loggable {
  final int count;
  const Count(this.count);

  @override
  List<Object> get props => [count];

  @override
  String toString() {
    return count.toString();
  }
}

class PendingRequestsCountCubit extends LoggingCubit<Count> {
  PendingRequestsCountCubit() : super(const Count(0));

  final FlutterEnrollmentService _enrollmentService = FlutterEnrollmentService();
  StreamSubscription<ServerEnrollmentRequest>? _subscription;

  /// Starts tracking pending enrollment requests. Must only be called once an
  /// AtClient exists (i.e. after onboarding) - the enrollment service
  /// dereferences the current AtClient, which throws pre-onboarding.
  void start() {
    _subscription ??= _enrollmentService.getEnrollments().listen(
      (_) => getPendingRequests(),
    );
    getPendingRequests();
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    emit(const Count(0));
  }

  Future<void> getPendingRequests() async {
    final atLookUp = AtClientManager.getInstance().atClient
        .getRemoteSecondary()!
        .atLookUp;
    final requests = await _enrollmentService.list(
      [EnrollmentStatus.pending],
      atLookUp,
    );
    emit(Count(requests.length));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
