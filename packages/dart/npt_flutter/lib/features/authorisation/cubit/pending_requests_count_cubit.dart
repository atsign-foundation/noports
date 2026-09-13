import 'dart:async';

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

  StreamSubscription<Enrollment>? _subscription;

  /// Starts tracking pending enrollment requests. Must only be called once an
  /// AtClient exists (i.e. after onboarding) - the count is read off the
  /// current AtClient, which throws pre-onboarding.
  void start() {
    _subscription ??= _client.enrollments.requests.listen(
      (_) => getPendingRequests(),
    );
    getPendingRequests();
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    emit(const Count(0));
  }

  AtClient get _client => AtClientManager.getInstance().atClient;

  Future<void> getPendingRequests() async {
    final requests = await _client.enrollments.pending();
    emit(Count(requests.length));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
