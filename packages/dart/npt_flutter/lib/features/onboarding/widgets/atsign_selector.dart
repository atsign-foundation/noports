import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';

class AtsignSelector extends StatefulWidget {
  const AtsignSelector({
    required this.options,
    super.key,
  });
  final Map<String, AtsignInformation> options;
  @override
  State<AtsignSelector> createState() => _AtsignSelectorState();
}

class _AtsignSelectorState extends State<AtsignSelector> {
  final focusNode = FocusNode();
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(builder: (context, state) {
      controller.value = TextEditingValue(text: state.atSign);
      return TextFormField(
        controller: controller,
        onChanged: (atsign) {
          context.read<OnboardingCubit>().setState(
                atSign: atsign,
                rootDomain: widget.options[atsign]?.rootDomain,
              );
        },
        decoration: InputDecoration(
          /// This menuAnchor is a dropdown button that allows you to quickly select
          /// existing values from [options]
          suffixIcon: widget.options.isNotEmpty
              ? Directionality(
                  textDirection: TextDirection.rtl,
                  child: MenuAnchor(
                    style: const MenuStyle(alignment: AlignmentDirectional.bottomStart),
                    childFocusNode: focusNode,
                    menuChildren: widget.options.keys.map((atsign) {
                      return Directionality(
                        textDirection: TextDirection.ltr,
                        child: MenuItemButton(
                          child: Text(atsign),
                          onPressed: () {
                            context.read<OnboardingCubit>().setState(
                                  atSign: atsign,
                                  rootDomain: widget.options[atsign]?.rootDomain,
                                );
                          },
                        ),
                      );
                    }).toList(),
                    builder: (BuildContext context, MenuController controller, Widget? child) {
                      return IconButton(
                        focusNode: focusNode,
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: const Icon(Icons.arrow_drop_down),
                      );
                    },
                  ),
                )
              : null,
        ),
      );
    });
  }
}
