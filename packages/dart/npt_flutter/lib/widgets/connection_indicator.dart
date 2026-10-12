import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/util/at_client_methods.dart';

/// A dot that says whether the current client's atServer connection is
/// online, offline or refused, following the client the app switches to.
class ConnectionIndicator extends StatefulWidget {
  const ConnectionIndicator({super.key});

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator>
    implements AtSignChangeListener {
  StreamSubscription<AtConnectionState>? _subscription;
  AtConnectionState? _state;

  @override
  void initState() {
    super.initState();
    _follow(AtClientMethods.currentClientOrNull());
    AtClientManager.getInstance().listenToAtSignChange(this);
  }

  @override
  void listenToAtSignChange(SwitchAtSignEvent switchAtSignEvent) {
    _follow(switchAtSignEvent.newAtClient);
  }

  void _follow(AtClient? client) {
    _subscription?.cancel();
    _subscription = null;
    if (client == null) {
      setState(() => _state = null);
      return;
    }
    setState(() => _state = client.connection.current);
    _subscription = client.connection.changes.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    AtClientManager.getInstance().removeChangeListeners(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) return const SizedBox.shrink();
    final (String label, Color color) = switch (state.outcome) {
      AtConnectionOutcome.online => ('Online', Colors.green),
      AtConnectionOutcome.offline => (
          'Offline: ${state.cause?.name ?? 'atServer not reached'}',
          Colors.orange
        ),
      AtConnectionOutcome.refused => (
          'Refused by the atServer: ${state.cause?.name ?? 'unknown'}',
          Colors.red
        ),
    };
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Icon(Icons.circle, size: 10, color: color),
      ),
    );
  }
}
