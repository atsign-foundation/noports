import 'package:flutter/material.dart';

class CustomTableCell extends StatelessWidget {
  const CustomTableCell({
    required this.child,
    this.text = '',
    super.key,
  });

  const CustomTableCell.text({
    super.key,
    this.child = const SizedBox(),
    required this.text,
  });

  final Widget child;
  final String text;

  @override
  Widget build(BuildContext context) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: text.isNotEmpty ? Text(text) : child,
        ),
      ),
    );
  }
}
