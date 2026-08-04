import 'dart:async';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:at_lookup/at_lookup.dart';

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
  PendingRequestsCountCubit(this._enrollmentService) : super(const Count(0)) {
    // Update the count whenever a new request is made
    _subscription = _enrollmentService.getEnrollments().listen(
      (_) => getPendingRequests(),
    );
    getPendingRequests();
  }

  final FlutterEnrollmentService _enrollmentService;
  StreamSubscription<EnrollmentServerResponse>? _subscription;

  Future<void> getPendingRequests() async {
    final AtLookUp? atLookUp = AtClientManager.getInstance().atClient
        .getRemoteSecondary()
        ?.atLookUp;
    if (atLookUp == null) {
      emit(const Count(0));
      return;
    }
    final requests = await _enrollmentService.list([
      EnrollmentStatus.pending,
    ], atLookUp);
    emit(Count(requests.length));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
