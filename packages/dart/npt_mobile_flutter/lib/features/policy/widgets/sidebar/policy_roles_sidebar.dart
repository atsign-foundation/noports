import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/policy_cubit.dart';
import '../../../../widgets/custom_card.dart';
import '../../../../styles/sizes.dart';
import 'roles_list_widget.dart';
import 'sidebar_header_widget.dart';
import 'sidebar_action_buttons_widget.dart';

class PolicyRolesSidebar extends StatelessWidget {
  const PolicyRolesSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return BlocBuilder<PolicyCubit, PolicyState>(
      builder: (context, state) {
        return SizedBox(
          width: isMobile ? double.infinity : 255,
          height: isMobile ? null : MediaQuery.of(context).size.height,
          child: CustomCard.settingsRail(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
              children: [
                const SidebarHeaderWidget(),
                const SidebarActionButtonsWidget(),
                gapH16,
                if (isMobile)
                  RolesListWidget(state: state)
                else
                  Expanded(child: RolesListWidget(state: state)),
              ],
            ),
          ),
        );
      },
    );
  }
}
