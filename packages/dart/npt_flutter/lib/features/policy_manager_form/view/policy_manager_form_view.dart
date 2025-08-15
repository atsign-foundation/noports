import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import '../../policy_manager/bloc/policy_manager_bloc.dart';
import '../../policy_manager/bloc/policy_manager_state.dart';
import '../widgets/form_content.dart';

class PolicyManagerFormView extends StatelessWidget {
  final Role role;

  const PolicyManagerFormView({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PolicyManagerBloc, PolicyManagerState>(
      builder: (context, state) {
        if (state is PolicyManagerLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is PolicyManagerError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        } else if (state is PolicyManagerRoleLoaded) {
          final selectedRole = state.selectedRole ?? role;
          return _buildForm(context, selectedRole, state);
        } else {
          return const Center(
            child: Text('No role selected'),
          );
        }
      },
    );
  }

  Widget _buildForm(BuildContext context, Role role, PolicyManagerRoleLoaded state) {
    return FormContent(role: role, state: state);
  }
}