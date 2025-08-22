import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/logs_viewer.dart';
import '../cubit/policy_logs_cubit.dart';
import '../../../styles/sizes.dart';

class PolicyLogsPage extends StatelessWidget {
  const PolicyLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PolicyLogsCubit(),
      child: Padding(
        padding: const EdgeInsets.all(Sizes.p16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Policy Logs',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Sizes.p8),
            Text(
              'Monitor policy requests and device activity across all roles',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: Sizes.p24),
            const Expanded(
              child: LogsViewer(),
            ),
          ],
        ),
      ),
    );
  }
}