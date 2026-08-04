import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/util/form_validator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AtsignSelector extends StatefulWidget {
  const AtsignSelector({
    this.options,

    /// Prevent the text field from showing the last used Atsign. Desirable when signing in but not when activating a new Atsign.
    this.isInSignInFlow = true,
    super.key,
  });
  final Map<String, AtsignInformation>? options;
  final bool isInSignInFlow;
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
      child: BlocBuilder<OnboardingCubit, OnboardingState>(
        builder: (context, state) {
          // Only update controller if the state value is different (e.g., from dropdown selection)
          if (controller.text != state.atsign && widget.isInSignInFlow) {
            controller.value = TextEditingValue(
              text: state.atsign ?? '',
              selection: TextSelection.collapsed(
                offset: (state.atsign ?? '').length,
              ),
            );
          }
          return TextFormField(
            controller: controller,
            onChanged: (atsign) {
              context.read<OnboardingCubit>().setState(
                atsign: atsign.toAtsign(),
                rootDomain: widget.options?[atsign]?.rootDomain,
              );
              // Resetting the multiActivationCubitState will set the MultiActivationFileUploadState to idle allowing the "Next" button (manual activation button) to be visible in the dialog. This is only required when multiActivationCubitState is error.
              final multiActivationCubitState = context
                  .read<MultiActivationCubit>();
              if (multiActivationCubitState.state.uploadState ==
                  MultiActivationFileUploadState.error) {
                multiActivationCubitState.reset();
              }
            },
            validator: FormValidator.validateRequiredAtsignField,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              /// This menuAnchor is a dropdown button that allows you to quickly select
              /// existing values from [options]
              suffixIcon: widget.options?.isNotEmpty ?? false
                  ? Directionality(
                      textDirection: TextDirection.rtl,
                      child: MenuAnchor(
                        style: const MenuStyle(
                          alignment: AlignmentDirectional.bottomStart,
                        ),
                        childFocusNode: focusNode,
                        menuChildren:
                            widget.options?.keys.map((atsign) {
                              return Directionality(
                                textDirection: TextDirection.ltr,
                                child: MenuItemButton(
                                  child: Text(atsign),
                                  onPressed: () {
                                    context.read<OnboardingCubit>().setState(
                                      atsign: atsign.toAtsign(),
                                      rootDomain:
                                          widget.options?[atsign]?.rootDomain,
                                    );
                                  },
                                ),
                              );
                            }).toList() ??
                            [],
                        builder:
                            (
                              BuildContext context,
                              MenuController controller,
                              Widget? child,
                            ) {
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
        },
      ),
    );
  }
}
