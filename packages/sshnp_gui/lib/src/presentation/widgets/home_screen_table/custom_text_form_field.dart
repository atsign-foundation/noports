import 'package:flutter/material.dart';

class CustomTextFormField extends StatelessWidget {
  const CustomTextFormField({
    super.key,
    required this.labelText,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.hintText,
    this.width = 192,
    this.height = 33,
  });

  final String labelText;
  final String? hintText;
  final String? initialValue;
  final double width;
  final double height;
  final void Function(String?)? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      // height: height,
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          labelText: labelText,
          hintText: hintText,
          hintStyle: Theme.of(context).textTheme.bodyLarge,
        ),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}
