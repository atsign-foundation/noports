import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/utility/constants.dart';

class CustomDropdownFormField<T> extends StatelessWidget {
  const CustomDropdownFormField({
    required this.label,
    required this.items,
    super.key,
    this.onChanged,
    this.hintText,
    this.width = kFieldDefaultWidth,
    this.height = kFieldDefaultHeight,
  });

  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String label;
  final String? hintText;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      // height: height,
      child: DropdownButtonFormField<T>(
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          isDense: true,
          label: Text(label),
          hintText: hintText,
          hintStyle: Theme.of(context).textTheme.bodyLarge,
          filled: true,
          fillColor: kProfileFormFieldColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
