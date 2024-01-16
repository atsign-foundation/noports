import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';

import '../../../../utility/sizes.dart';

class CustomSwitchWidget extends StatelessWidget {
  const CustomSwitchWidget({
    required this.labelText,
    required this.value,
    required this.onChanged,
    this.tooltip = '',
    super.key,
  });

  final String labelText;
  final bool value;
  final void Function(bool)? onChanged;
  final String tooltip;

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
          gapW8,
          Tooltip(
            message: tooltip,
            child: const Icon(
              Icons.question_mark_outlined,
              size: 12,
            ),
          )
        ],
      ),
    );
  }
}
