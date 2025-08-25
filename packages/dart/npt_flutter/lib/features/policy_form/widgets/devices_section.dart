import 'package:flutter/material.dart';
import '../../policy/models/policy.dart';
import 'device_card.dart';

class DevicesSection extends StatelessWidget {
  final List<Device> devices;
  final bool isEditing;

  const DevicesSection({super.key, required this.devices, required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Devices',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isEditing)
              TextButton.icon(
                onPressed: () {
                  // TODO: Add device functionality
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Device'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (devices.isEmpty)
          const Text(
            'No devices configured',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...devices.map((device) => DeviceCard(device: device, isEditing: isEditing)),
      ],
    );
  }
}