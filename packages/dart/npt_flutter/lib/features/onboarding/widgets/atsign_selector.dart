import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/util/form_validator.dart';
import 'package:npt_flutter/util/general_extensions.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
    return SizedBox(
      width: double.infinity,
      child: BlocBuilder<OnboardingCubit, OnboardingState>(builder: (context, state) {
        controller.value =
            TextEditingValue(text: state.atSign, selection: TextSelection.collapsed(offset: state.atSign.length));
        return TextFormField(
          controller: controller,
          onChanged: (atsign) {
            atsign = atsign.atsignify();
            controller.value =
                TextEditingValue(text: atsign, selection: TextSelection.collapsed(offset: atsign.length));
            context.read<OnboardingCubit>().setState(
                  atSign: atsign,
                  rootDomain: widget.options[atsign]?.rootDomain,
                );
          },
          validator: FormValidator.validateRequiredAtsignField,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                          icon: Icon(
                            PhosphorIcons.caretDown(),
                            color: AppColor.primaryColor,
                          ),
                        );
                      },
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }
}
