import 'package:flutter/material.dart';

import '../../../utility/sizes.dart';

class CustomSwitchWidget extends StatelessWidget {
  const CustomSwitchWidget({required this.labelText, required this.value, required this.onChanged, super.key});

  final String labelText;
  final bool value;
  final void Function(bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(labelText)),
        gapW8,
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
