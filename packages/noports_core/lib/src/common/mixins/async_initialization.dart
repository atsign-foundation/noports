import 'dart:async';

import 'package:meta/meta.dart';

mixin class AsyncInitialization {
  // * Private members
  bool _initializeStarted = false;
  final Completer<void> _initializedCompleter = Completer<void>();

  // * Public members

  /// Used to check if initialization has started
  bool get initializeStarted => _initializeStarted;

  /// Used to check if initialization has completed
  Future<void> get initialized => _initializedCompleter.future;

  // * Protected members

  /// Used to check if it is safe to do an initialization step
  /// (i.e. if initialization has not yet completed)
  @protected
  bool get isSafeToInitialize => !_initializedCompleter.isCompleted;

  /// To be called by the class that implements this mixin
  /// to ensure that [initialize] is only called once
  @visibleForTesting
  @protected
  Future<void> callInitialization() async {
    if (!_initializeStarted) {
      _initializeStarted = true;
      unawaited(initialize());
    }
    return initialized;
  }

  /// To be overridden by the class that implements this mixin
  /// to perform initialization steps. Do not call this method directly.
  /// Instead, call [callInitialization] to ensure that initialization
  /// is only done once.
  ///
  /// hint: call [completeInitialization] at the end of this method
  /// to signal completion of the initialization process
  ///
  /// hint: call [isSafeToInitialize] at the beginning of this method
  /// to ensure that initialization is not done more than once
  @visibleForTesting
  @visibleForOverriding
  @protected
  Future<void> initialize() async {}

  /// To be called by the class that implements this mixin
  /// to signal completion of the initialization process
  /// hint: call this in the last line of [initialize]
  @visibleForTesting
  @protected
  void completeInitialization() {
    if (isSafeToInitialize) _initializedCompleter.complete();
  }
}
