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
    return BlocBuilder<PolicyCubit, PolicyState>(
      builder: (context, state) {
        return SizedBox(
          width: 255,
          height: MediaQuery.of(context).size.height,
          child: CustomCard.settingsRail(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SidebarHeaderWidget(),
                const SidebarActionButtonsWidget(),
                gapH16,
                Expanded(
                  child: RolesListWidget(state: state),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
