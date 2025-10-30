import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../../../../styles/app_color.dart';
import '../../cubit/policy_cubit.dart';

class SidebarActionButtonsWidget extends StatelessWidget {
  const SidebarActionButtonsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        //   child: SizedBox(
        //     height: 48,
        //     width: double.infinity,
        //     child: BlocBuilder<PolicyCubit, PolicyState>(
        //       builder: (context, state) {
        //         final isLogsView = state is PolicyViewingLogs;
        //         return OutlinedButton.icon(
        //           onPressed: () {
        //             context.read<PolicyCubit>().showLogs();
        //           },
        //           icon: const Icon(Icons.list_alt),
        //           label: Text(strings.logsView),
        //           style: OutlinedButton.styleFrom(
        //             foregroundColor: isLogsView
        //                 ? Colors.white
        //                 : AppColor.primaryColor,
        //             backgroundColor: isLogsView ? AppColor.primaryColor : null,
        //             side: const BorderSide(color: AppColor.primaryColor),
        //             shape: const RoundedRectangleBorder(
        //               borderRadius: BorderRadius.zero,
        //             ),
        //           ),
        //         );
        //       },
        //     ),
        //   ),
        // ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: BlocBuilder<PolicyCubit, PolicyState>(
              builder: (context, state) {
                return ElevatedButton.icon(
                  onPressed:
                      (state is PolicyEditingRole ||
                          state is PolicyCreatingRole)
                      ? null
                      : () {
                          context.read<PolicyCubit>().startCreatingRole();
                        },
                  icon: const Icon(Icons.add),
                  label: Text(strings.roleAddNew),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primaryColor,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
