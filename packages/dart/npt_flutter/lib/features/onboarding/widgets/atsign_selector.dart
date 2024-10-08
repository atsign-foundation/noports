import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/logging/models/loggable.dart';
import 'package:npt_flutter/features/onboarding/cubit/at_directory_cubit.dart';

typedef OnboardingMapCallback = void Function(Map<String, String> val);

class AtsignSelector extends StatefulWidget {
  AtsignSelector({
    super.key,
  });

  final List<String> options = [];

  @override
  State<AtsignSelector> createState() => _AtsignSelectorState();
}

class _AtsignSelectorState extends State<AtsignSelector> {
  final FocusNode focusNode = FocusNode();

  final TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AtDirectoryCubit, LoggableString>(builder: (context, rootDomain) {
      controller.text = rootDomain.string;
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: DropdownMenu<String>(
                  initialSelection: widget.options.contains(rootDomain.string) ? rootDomain.string : null,
                  dropdownMenuEntries: widget.options
                      .map<DropdownMenuEntry<String>>(
                        (o) => DropdownMenuEntry(
                          value: o,
                          label: o,
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value == null) return;

                    context.read<AtDirectoryCubit>().setRootDomain(value);
                  },
                ),
              ),
              Flexible(
                child: KeyboardListener(
                  focusNode: focusNode,
                  onKeyEvent: (value) {
                    if (value.logicalKey == LogicalKeyboardKey.backspace) {
                      if (widget.options.length > 2) widget.options.removeLast();
                    }
                  },
                  child: TextFormField(
                    controller: controller,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    // validator: FormValidator.validateRequiredAtsignField,
                    onChanged: (value) {
                      // prevent the user from adding the default values to the dropdown a second time.
                      if (value != widget.options[0] || value != widget.options[1]) {
                        widget.options.add(value);
                      }
                      //removes the third element making the final entry the only additional value in options. This prevents the dropdown from having more than 3 entries.
                      if (widget.options.length > 3) widget.options.removeAt(2);

                      context.read<AtDirectoryCubit>().setRootDomain(value);
                    },
                  ),
                ),
              )
            ],
          ),
        ],
      );
    });
  }
}
