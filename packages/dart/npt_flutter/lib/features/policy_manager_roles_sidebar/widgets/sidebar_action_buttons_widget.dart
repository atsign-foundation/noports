import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/cubit/policy_manager_cubit.dart';
import '../../../styles/app_color.dart';

class SidebarActionButtonsWidget extends StatelessWidget {
  const SidebarActionButtonsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // View Logs Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: BlocBuilder<PolicyManagerCubit, PolicyManagerState>(
              builder: (context, state) {
                final isLogsView = state is PolicyManagerLoaded && state.isLogsViewing;
                return OutlinedButton.icon(
                  onPressed: () {
                    context.read<PolicyManagerCubit>().showLogs();
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View Logs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isLogsView ? Colors.white : AppColor.primaryColor,
                    backgroundColor: isLogsView ? AppColor.primaryColor : null,
                    side: const BorderSide(color: AppColor.primaryColor),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Add New Role Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: BlocBuilder<PolicyManagerCubit, PolicyManagerState>(
              builder: (context, state) {
                return ElevatedButton.icon(
                  onPressed: (state is PolicyManagerLoaded && state.isInEditMode) 
                    ? null 
                    : () {
                        context.read<PolicyManagerCubit>().startCreatingRole();
                      },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Role'),
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