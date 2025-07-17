import 'package:flutter/material.dart';
import '../../policy_manager/models/policy.dart';

class DeviceGroupCard extends StatelessWidget {
  final DeviceGroup group;
  final bool isEditing;

  const DeviceGroupCard({super.key, required this.group, required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.group_work),
        title: Text(group.name),
        subtitle: Text('Permit Opens: ${group.permitOpens.join(', ')}'),
        trailing: isEditing
            ? IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  // TODO: Remove device group functionality
                },
              )
            : null,
      ),
    );
  }
}