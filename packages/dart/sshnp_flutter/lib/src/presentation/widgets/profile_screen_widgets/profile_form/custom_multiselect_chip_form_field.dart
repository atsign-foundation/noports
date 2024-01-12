import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/form_validator.dart';

import '../../../../utility/sizes.dart';
import '../../ssh_key_management/ssh_key_management_form_dialog.dart';

class CustomMultiSelectChipFormField<T> extends StatefulWidget {
  const CustomMultiSelectChipFormField({
    required this.label,
    required this.items,
    required this.selectedItems,
    super.key,
    this.onChanged,
    this.onSaved,
    this.onValidator,
    this.hintText,
    this.width = kFieldDefaultWidth,
    this.height = Sizes.p163,
  });

  final List<String> items;
  final List<String> selectedItems;
  final void Function(T?)? onChanged;
  final void Function(T?)? onSaved;
  final String? Function(T?)? onValidator;
  final String label;
  final String? hintText;
  final double width;
  final double height;

  @override
  State<CustomMultiSelectChipFormField<T>> createState() =>
      _CustomMultiSelectChipFormFieldState<T>();
}

class _CustomMultiSelectChipFormFieldState<T>
    extends State<CustomMultiSelectChipFormField<T>> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    log('selectedItems: ${widget.selectedItems}');
    return SizedBox(
      // width: kFieldDefaultWidth + 210,
      height: widget.height,
      child: FormField<List<String>>(
        initialValue: widget.selectedItems,
        validator: FormValidator.validateMultiSelectStringField,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                widget.label,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                strings.privateKeyDescription,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Colors.grey,
                    ),
              ),
              trailing: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(58),
                  ),
                ),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: ((context) =>
                          const SSHKeyManagementFormDialog()));
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add New'),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: kPrivateKeyGridBackgroundColor,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 4,
                          ),
                          itemCount: widget.items.length,
                          itemBuilder: (BuildContext context, int index) =>
                              InputChip(
                            backgroundColor: kInputChipBackgroundColor,
                            showCheckmark: true,
                            selectedColor: kPrimaryColor,
                            label: SizedBox(
                                width: 210,
                                // height: 30,
                                child: Text(
                                  widget.items[index],
                                )),
                            onSelected: (bool value) {
                              setState(() {
                                if (value) {
                                  widget.selectedItems.add(widget.items[index]);
                                } else {
                                  widget.selectedItems
                                      .remove(widget.items[index]);
                                }
                              });
                            },
                            selected: widget.selectedItems
                                .contains(widget.items[index]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            gapH4,
            if (state.hasError)
              Text(
                state.errorText!,
                style: theme.textTheme.bodySmall!
                    .copyWith(color: theme.colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
