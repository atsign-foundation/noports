import 'dart:async';

import 'package:flutter/material.dart';
import 'package:npt_flutter/features/authorisation/util/pretty_duration.dart';

class SppExpiration extends StatefulWidget {
  const SppExpiration({
    required this.expiryTime,
    required this.onExpiry,
    super.key,
  });

  final DateTime expiryTime;
  final VoidCallback onExpiry;

  @override
  State<SppExpiration> createState() => _SppExpirationState();
}

class _SppExpirationState extends State<SppExpiration> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    if (!mounted) return;
    if (DateTime.now().isAfter(widget.expiryTime)) {
      timer.cancel();
      widget.onExpiry();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration remaining = widget.expiryTime.difference(DateTime.now());
    return Text(
      'Current pin expires in ${prettyDuration(remaining)}',
      style: Theme.of(context).textTheme.bodyLarge,
      textAlign: TextAlign.center,
    );
  }
}
