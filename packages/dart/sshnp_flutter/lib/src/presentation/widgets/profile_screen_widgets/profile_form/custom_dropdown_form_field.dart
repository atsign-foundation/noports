import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

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
    this.tooltip = '',
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
  final String tooltip;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final bodySmall = Theme.of(context).textTheme.bodySmall!;
    return SizedBox(
      width: width.toWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: bodySmall.copyWith(
              color: Colors.grey,
              fontSize: bodySmall.fontSize?.toFont,
            ),
          ),
          DropdownButtonFormField<T>(
            value: initialValue,
            style: bodySmall.copyWith(
              color: Colors.black,
              fontSize: bodySmall.fontSize?.toFont,
            ),
            selectedItemBuilder: (context) => items
                .map((e) => Text(
                      e.value.toString(),
                      style: bodySmall.copyWith(
                        color: kPrimaryColor,
                        // fontSize: bodySmall.fontSize?.toFont,
                      ),
                    ))
                .toList(),
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              hintStyle: bodySmall.copyWith(fontSize: bodySmall.fontSize?.toFont),
              filled: true,
              fillColor: kProfileFormFieldColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              errorMaxLines: 3,
              suffixIcon: Tooltip(
                message: tooltip,
                child: const Icon(
                  Icons.question_mark_outlined,
                  color: kPrimaryColor,
                  size: 12,
                ),
              ),
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
