import 'dart:async';

import 'package:meta/meta.dart';

mixin class AsyncDisposal {
  // * Private members
  bool _disposalStarted = false;
  final Completer<void> _disposedCompleter = Completer<void>();

  // * Public members

  /// Used to check if disposal has started
  bool get disposalStarted => _disposalStarted;

  /// Used to check if disposal has completed
  Future<void> get disposed => _disposedCompleter.future;

  // * Protected members

  /// Used to check if it is safe to do a disposal step
  /// (i.e. if disposal has not yet completed)
  @protected
  bool get isSafeToDispose => !_disposedCompleter.isCompleted;

  @protected
  Future<void> callDisposal() async {
    if (!_disposalStarted) {
      _disposalStarted = true;
      unawaited(dispose());
    }
    return disposed;
  }

  /// To be overridden by the class that implements this mixin
  /// to perform disposal steps. Do not call this method directly.
  /// Instead, call [callDisposal] to ensure that disposal
  /// is only done once.
  ///
  /// hint: call [completeDisposal] at the end of this method
  /// to signal completion of the disposal process
  ///
  /// hint: call [isSafeToDispose] at the beginning of this method
  /// to ensure that disposal is not done more than once
  @visibleForOverriding
  @protected
  Future<void> dispose() async {}

  /// To be called by the class that implements this mixin
  /// to signal completion of the disposal process
  /// hint: call this in the last line of [dispose]
  @protected
  void completeDisposal() {
    if (isSafeToDispose) _disposedCompleter.complete();
  }
}
