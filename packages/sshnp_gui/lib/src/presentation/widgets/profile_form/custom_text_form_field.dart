import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/utility/constants.dart';

class CustomTextFormField extends StatefulWidget {
  const CustomTextFormField({
    super.key,
    required this.labelText,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.hintText,
    this.width = kFieldDefaultWidth,
    this.height = kFieldDefaultHeight,
    this.isPasswordField = false,
  });

  final String labelText;
  final String? hintText;
  final String? initialValue;
  final double width;
  final double height;
  final void Function(String)? onChanged;
  final void Function(String?)? onSaved;
  final String? Function(String?)? validator;
  final bool isPasswordField;

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  bool _isPasswordVisible = false;

  void _setPasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      // height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.labelText,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: Colors.grey,
                ),
          ),
          TextFormField(
            initialValue: widget.initialValue,
            obscureText: widget.isPasswordField && !_isPasswordVisible,
            decoration: InputDecoration(
              filled: true,
              fillColor: kProfileFormFieldColor,
              border: UnderlineInputBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              hintText: widget.hintText,
              hintStyle: Theme.of(context).textTheme.bodyLarge,
              suffixIcon: widget.isPasswordField
                  ? InkWell(
                      onTap: _setPasswordVisibility,
                      child: Icon(_isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    )
                  : null,
            ),
            onChanged: widget.onChanged,
            onSaved: widget.onSaved,
            validator: widget.validator,
          ),
        ],
      ),
    );
  }
}
