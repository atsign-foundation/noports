import 'dart:async';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
// TODO: remove if we decide that at_client_flutter should export this.
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
  PendingRequestsCountCubit(this._authorisationService)
    : super(const Count(0)) {
    // Update the count whenever a new request is made
    _subscription = _authorisationService.getEnrollments().listen(
      (_) => getPendingRequests(),
    );
    getPendingRequests();
  }

  final FlutterEnrollmentService _authorisationService;
  StreamSubscription<EnrollmentServerResponse>? _subscription;

  Future<void> getPendingRequests() async {
    final atClient = AtClientManager.getInstance().atClient;
    final currentAtSign = atClient.getCurrentAtSign();
    final prefs = atClient.getPreferences();

    if (currentAtSign == null || prefs == null) {
      emit(const Count(0));
      return;
    }

    final atLookUp = AtLookupImpl(
      currentAtSign,
      prefs.rootDomain,
      prefs.rootPort,
    );

    try {
      final requests = await _authorisationService.list([
        EnrollmentStatus.pending,
      ], atLookUp);
      emit(Count(requests.length));
    } finally {
      await atLookUp.close();
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
