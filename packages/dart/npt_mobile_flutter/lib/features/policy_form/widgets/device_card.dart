import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';

import '../../policy/models/policy.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final bool isEditing;

  const DeviceCard({super.key, required this.device, required this.isEditing});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.computer),
        title: Text(device.name),
        subtitle: Text(strings.permitOpens(device.permitOpens.join(', '))),
        trailing: isEditing
            ? IconButton(icon: const Icon(Icons.delete), onPressed: () {})
            : null,
      ),
    );
  }
}
