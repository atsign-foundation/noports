import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy/models/policy.dart';
import '../../policy/cubit/policy_cubit.dart';
import '../../policy/repositories/role_repository.dart';
import '../cubit/policy_form_cubit.dart';
import '../widgets/form_content.dart';

class PolicyFormView extends StatelessWidget {
  final Role role;

  const PolicyFormView({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PolicyFormCubit(context.read<RoleRepository>()),
      child: BlocBuilder<PolicyCubit, PolicyState>(
        builder: (context, state) {
          if (state is PolicyLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is PolicyError) {
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
          } else if (state is PolicyLoaded) {
            final selectedRole = state.selectedRole ?? role;
            return _buildForm(context, selectedRole, state);
          } else {
            return const Center(
              child: Text('No role selected'),
            );
          }
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, Role role, PolicyLoaded state) {
    return FormContent(role: role, state: state);
  }
}