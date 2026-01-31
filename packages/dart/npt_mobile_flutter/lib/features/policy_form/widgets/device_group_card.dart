import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';

import '../../policy/models/policy.dart';

class DeviceGroupCard extends StatelessWidget {
  final DeviceGroup group;
  final bool isEditing;

  const DeviceGroupCard({
    super.key,
    required this.group,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.group_work),
        title: Text(group.name),
        subtitle: Text(strings.permitOpens(group.permitOpens.join(', '))),
        trailing: isEditing
            ? IconButton(icon: const Icon(Icons.delete), onPressed: () {})
            : null,
      ),
    );
  }
}
