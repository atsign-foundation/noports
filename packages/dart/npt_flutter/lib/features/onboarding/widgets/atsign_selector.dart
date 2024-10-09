import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/at_directory_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';

typedef OnboardingMapCallback = void Function(Map<String, String> val);

class AtsignSelector extends StatefulWidget {
  const AtsignSelector({
    super.key,
  });

  @override
  State<AtsignSelector> createState() => _AtsignSelectorState();
}

class _AtsignSelectorState extends State<AtsignSelector> {
  final FocusNode focusNode = FocusNode();

  final TextEditingController controller = TextEditingController();
  List<String> options = [];
  late final List<String> originalOptions;

  late int originalOptionsLength;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      options = (await getAtsignEntries()).keys.toList();
      if (mounted) context.read<AtDirectoryCubit>().setAtSign(options[0]);

      controller.text = options[0];
      originalOptions = List.from(options);
      originalOptionsLength = options.length;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AtDirectoryCubit, AtsignInformation>(builder: (context, atsignInformation) {
      controller.text = atsignInformation.atSign;
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: DropdownMenu<String>(
                  initialSelection:
                      options.contains(atsignInformation.atSign) ? atsignInformation.atSign : controller.text,
                  dropdownMenuEntries: options
                      .map<DropdownMenuEntry<String>>(
                        (o) => DropdownMenuEntry(
                          value: o,
                          label: o,
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value == null) return;

                    context.read<AtDirectoryCubit>().setAtSign(value);
                  },
                ),
              ),
              Flexible(
                child: KeyboardListener(
                  focusNode: focusNode,
                  onKeyEvent: (value) {
                    if (value.logicalKey == LogicalKeyboardKey.backspace) {
                      if (options.length > originalOptionsLength) options.removeLast();
                    }
                  },
                  child: TextFormField(
                    controller: controller,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    // validator: FormValidator.validateRequiredAtsignField,
                    onChanged: (value) {
                      // prevent the user from adding the default values to the dropdown a second time.
                      if (!originalOptions.contains(value)) {
                        options.add(value);

                        setState(() {});
                      }
                      //removes the last element making the final entry the only additional value in options. This prevents the dropdown from having more than original options + one entries.
                      if (options.length > originalOptionsLength + 1) options.removeAt(originalOptionsLength);

                      context.read<AtDirectoryCubit>().setAtSign(value);
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
