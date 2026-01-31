import 'dart:async';

import 'package:at_client_mobile/at_client_mobile.dart';

import '../../logging/models/logging_bloc.dart';
import '../../logging/models/loggable.dart';

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

// TODO: Authorization features are not available on mobile (server-only feature)
// Stubbed out until mobile support is added
class PendingRequestsCountCubit extends LoggingCubit<Count> {
  PendingRequestsCountCubit() : super(const Count(0)) {
    // Authorization service not available on mobile
    // _subscription = _authorisationService.enrollmentRequests().listen(
    //       (_) => getPendingRequests(),
    //     );
    // getPendingRequests();
  }

  // final AuthorisationService _authorisationService;
  // StreamSubscription<ServerEnrollmentRequest>? _subscription;

  Future<void> getPendingRequests() async {
    // Authorization service not available on mobile - always return 0
    emit(const Count(0));
    // final requests = await _authorisationService.getEnrollmentRequests(
    //   statusFilters: [EnrollmentStatus.pending],
    // );
    // emit(Count(requests.length));
  }

  @override
  Future<void> close() {
    // _subscription?.cancel();
    return super.close();
  }
}
