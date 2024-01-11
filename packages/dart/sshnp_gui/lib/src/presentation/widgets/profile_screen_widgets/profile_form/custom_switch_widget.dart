import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/utility/constants.dart';

import '../../../../utility/sizes.dart';

class CustomSwitchWidget extends StatelessWidget {
  const CustomSwitchWidget({required this.labelText, required this.value, required this.onChanged, super.key});

  final String labelText;
  final bool value;
  final void Function(bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kFieldDefaultWidth,
      child: Row(
        children: [
          Expanded(
              child: Text(
            labelText,
            style: Theme.of(context).textTheme.bodySmall,
          )),
          gapW8,
          Switch(
            activeColor: Colors.white,
            activeTrackColor: kPrimaryColor,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
