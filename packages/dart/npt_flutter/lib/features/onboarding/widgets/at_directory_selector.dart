import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';

class AtDirectorySelector extends StatefulWidget {
  const AtDirectorySelector({
    required this.options,
    super.key,
  });
  final Map<String, AtsignInformation> options;

  @override
  State<AtDirectorySelector> createState() => _AtDirectorySelectorState();
}

class _AtDirectorySelectorState extends State<AtDirectorySelector> {
  final focusNode = FocusNode();
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final rootDomains = Constants.getRootDomains(context);
    return BlocBuilder<OnboardingCubit, OnboardingState>(builder: (context, state) {
      controller.value = TextEditingValue(text: state.rootDomain);
      return TextFormField(
        enabled: !widget.options.containsKey(state.atSign),
        controller: controller,
        onChanged: (rootDomain) {
          context.read<OnboardingCubit>().setRootDomain(rootDomain);
        },
        decoration: InputDecoration(
          /// This menuAnchor is a dropdown button that allows you to quickly select
          /// existing values from [options]
          suffixIcon: rootDomains.isNotEmpty
              ? Directionality(
                  textDirection: TextDirection.rtl,
                  child: MenuAnchor(
                    style: const MenuStyle(alignment: AlignmentDirectional.bottomStart),
                    childFocusNode: focusNode,
                    menuChildren: rootDomains.entries.map((e) {
                      return Directionality(
                        textDirection: TextDirection.ltr,
                        child: MenuItemButton(
                          child: Text(e.value),
                          onPressed: () {
                            context.read<OnboardingCubit>().setRootDomain(e.key);
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
