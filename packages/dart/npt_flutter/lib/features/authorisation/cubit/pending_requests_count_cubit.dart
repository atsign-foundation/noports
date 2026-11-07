import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:window_manager/window_manager.dart';

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

class PendingRequestsCountCubit extends LoggingCubit<Count>
    with WindowListener {
  PendingRequestsCountCubit() : super(const Count(0));

  static final AtSignLogger _logger = AtSignLogger('PendingRequestsCountCubit');
  StreamSubscription<Enrollment>? _subscription;

  /// Starts tracking pending enrollment requests. Must only be called once an
  /// AtClient exists (i.e. after onboarding) - the count is read off the
  /// current AtClient, which throws pre-onboarding.
  void start() {
    if (_subscription == null) {
      _subscription = _client.enrollments.requests.listen(
        (_) => getPendingRequests(),
      );
      windowManager.addListener(this);
    }
    getPendingRequests();
  }

  void stop() {
    windowManager.removeListener(this);
    _subscription?.cancel();
    _subscription = null;
    emit(const Count(0));
  }

  AtClient get _client => AtClientManager.getInstance().atClient;

  /// Sets the count from a read of the pending requests made elsewhere, so
  /// the badge shows what the Requests list shows.
  void setCount(int count) {
    if (isClosed) return;
    emit(Count(count));
  }

  /// Requests decided elsewhere send no notification, so the count is read
  /// again whenever the window comes back into focus.
  @override
  void onWindowFocus() => unawaited(getPendingRequests());

  Future<void> getPendingRequests() async {
    try {
      final requests = await _client.enrollments.pending();
      setCount(requests.length);
    } catch (e, st) {
      // NOTE: a failed read says nothing new, so the last count stands; the
      // warning lets a badge that stops updating be traced.
      _logger.warning('Could not read the pending enrollment requests', e, st);
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    windowManager.removeListener(this);
    return super.close();
  }
}
