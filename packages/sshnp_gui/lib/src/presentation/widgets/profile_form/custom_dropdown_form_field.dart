import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/utility/constants.dart';

class CustomDropdownFormField<T> extends StatelessWidget {
  const CustomDropdownFormField({
    required this.label,
    required this.items,
    this.initialValue,
    super.key,
    this.onChanged,
    this.onSaved,
    this.hintText,
    this.width = kFieldDefaultWidth,
    this.height = kFieldDefaultHeight,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final void Function(T?)? onSaved;
  final String label;
  final String? hintText;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      // height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: Colors.grey,
                ),
          ),
          DropdownButtonFormField<T>(
            value: initialValue,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Colors.black),
            selectedItemBuilder: (context) => items
                .map((e) => Text(
                      e.value.toString(),
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: kPrimaryColor),
                    ))
                .toList(),
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              isDense: true,
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
            onSaved: onSaved,
          ),
        ],
      ),
    );
  }
}
