import 'dart:async';

import 'package:meta/meta.dart';

/// Keeps hold of the notification subscriptions a channel registers with
/// [track], so that they can all be cancelled when its session ends. Only the
/// subscriptions a session opens are registered; one-shot paths such as
/// listing devices aren't.
///
/// Without this, every session leaves its listeners attached to the
/// [AtClient]'s notification streams for the life of the process, each one
/// keeping its whole channel reachable. A client that retries a failing
/// session indefinitely - NoPorts Desktop's keep-alive, for one - would
/// accumulate them without bound.
mixin SubscriptionTracking {
  final List<StreamSubscription> _subscriptions = [];

  /// Registers [subscription] to be cancelled by [cancelSubscriptions].
  @protected
  StreamSubscription<T> track<T>(StreamSubscription<T> subscription) {
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Cancels every subscription registered via [track]. Safe to call more
  /// than once.
  Future<void> cancelSubscriptions() async {
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    await Future.wait(subscriptions.map((s) => s.cancel()));
  }
}
