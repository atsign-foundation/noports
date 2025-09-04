import 'package:flutter/material.dart';
import '../../policy/models/policy.dart';
import 'device_group_card.dart';

class DeviceGroupsSection extends StatelessWidget {
  final List<DeviceGroup> deviceGroups;
  final bool isEditing;

  const DeviceGroupsSection({super.key, required this.deviceGroups, required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Device Groups',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isEditing)
              TextButton.icon(
                onPressed: () {
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Group'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (deviceGroups.isEmpty)
          const Text(
            'No device groups configured',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...deviceGroups.map((group) => DeviceGroupCard(group: group, isEditing: isEditing)),
      ],
    );
  }
}