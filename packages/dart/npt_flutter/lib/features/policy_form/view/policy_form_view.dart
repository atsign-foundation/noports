import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy/models/policy.dart';
import '../cubit/policy_form_cubit.dart';
import '../widgets/form_content.dart';

class PolicyFormView extends StatelessWidget {
  final RoleInProgress role;
  final bool isEditing;

  const PolicyFormView({
    super.key, 
    required this.role,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PolicyFormCubit, PolicyFormState>(
      builder: (context, formState) {
        if (formState is PolicyFormLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (formState is PolicyFormError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: ${formState.message}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    return FormContent(
      key: ValueKey('form_${role.tempId}'),
    );
  }
}