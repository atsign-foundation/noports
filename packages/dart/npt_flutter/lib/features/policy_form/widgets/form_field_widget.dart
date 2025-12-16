import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/sizes.dart';

class FormFieldWidget extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? helperText;
  final int? maxLines;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  const FormFieldWidget({
    super.key,
    required this.label,
    required this.controller,
    required this.enabled,
    this.helperText,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        gapH8,
        SizedBox(
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            onChanged: onChanged,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: validator,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              helperText: helperText,
            ),
          ),
        ),
      ],
    );
  }
}
