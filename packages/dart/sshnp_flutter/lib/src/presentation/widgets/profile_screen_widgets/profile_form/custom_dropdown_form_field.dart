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
    this.onValidator,
    this.hintText,
    this.width = kFieldDefaultWidth,
    this.height = kFieldDefaultHeight,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final void Function(T?)? onSaved;
  final String? Function(T?)? onValidator;
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
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Colors.grey,
                ),
          ),
          DropdownButtonFormField<T>(
            value: initialValue,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.black),
            selectedItemBuilder: (context) => items
                .map((e) => Text(
                      e.value.toString(),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: kPrimaryColor),
                    ))
                .toList(),
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              hintStyle: Theme.of(context).textTheme.bodySmall,
              filled: true,
              fillColor: kProfileFormFieldColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              errorMaxLines: 3,
            ),
            items: items,
            onChanged: onChanged,
            onSaved: onSaved,
            validator: onValidator,
          ),
        ],
      ),
    );
  }
}
