import 'package:flutter/material.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/platform/device_names.dart';

/// "Use this computer's name": fills a device-name field with a valid name
/// made from the hostname.
class HostnameButton extends StatelessWidget {
  const HostnameButton({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return TextButton.icon(
      onPressed: () => onPick(DeviceNames.fromHostname()),
      icon: const Icon(Icons.computer_outlined, size: 16),
      label: Text(strings.hostname),
    );
  }
}
