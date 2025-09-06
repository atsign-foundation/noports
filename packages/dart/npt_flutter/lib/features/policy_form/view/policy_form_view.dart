import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../styles/app_color.dart';
import '../../policy/models/policy.dart';
import '../../policy/cubit/policy_cubit.dart';
import '../../policy/repositories/role_repository.dart';
import '../cubit/policy_form_cubit.dart';
import '../widgets/form_content.dart';

class PolicyFormView extends StatefulWidget {
  final RoleInProgress role;
  final bool isEditing;

  const PolicyFormView({
    super.key, 
    required this.role,
    this.isEditing = false,
  });

  @override
  State<PolicyFormView> createState() => _PolicyFormViewState();
}

class _PolicyFormViewState extends State<PolicyFormView> {
  late PolicyFormCubit _formCubit;

  @override
  void initState() {
    super.initState();
    _formCubit = PolicyFormCubit(
      context.read<RoleRepository>(),
      onSuccess: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColor.primaryColor,
            ),
          );
          context.read<PolicyCubit>().cancelEditing();
        }
      },
      onDeleted: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Role deleted successfully!'),
              backgroundColor: AppColor.primaryColor,
            ),
          );
          context.read<PolicyCubit>().loadRoles();
        }
      },
    );
    
    // Initialize the form after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formCubit.initializeWithRole(widget.role, isEditingMode: widget.isEditing);
    });
  }

  @override
  void dispose() {
    _formCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _formCubit,
      child: BlocBuilder<PolicyFormCubit, PolicyFormState>(
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
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return FormContent(
      key: ValueKey('form_${role.tempId}'),
    );
  }
}