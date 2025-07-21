import 'package:flutter/material.dart';

class FormFieldWidget extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? helperText;
  final int maxLines;
  final void Function(String)? onChanged;

  const FormFieldWidget({
    super.key,
    required this.label,
    required this.controller,
    required this.enabled,
    this.helperText,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              helperText: helperText,
              filled: !enabled,
              fillColor: enabled ? null : Colors.grey[100],
            ),
          ),
        ),
      ],
    );
  }
}