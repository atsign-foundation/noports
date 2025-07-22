import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/policy_manager_bloc.dart';
import '../bloc/policy_manager_event.dart';
import '../bloc/policy_manager_state.dart';
import '../models/policy.dart';
import '../repositories/role_repository.dart';
import '../../policy_manager_form/view/policy_manager_form_view.dart';

class PolicyManagerView extends StatelessWidget {
  final String atSign;
  
  const PolicyManagerView({super.key, required this.atSign});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PolicyManagerBloc(context.read<RoleRepository>())..add(const PolicyManagerLoadingRoles()),
      child: PolicyManagerContent(atSign: atSign),
    );
  }
}

class PolicyManagerContent extends StatelessWidget {
  final String atSign;
  
  const PolicyManagerContent({super.key, required this.atSign});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PolicyManagerBloc, PolicyManagerState>(
      builder: (context, state) {
        return Scaffold(
          body: Row(
            children: [
              _buildRolesSidebar(state, context),
              Expanded(
                child: _buildMainContent(state),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRolesSidebar(PolicyManagerState state, BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text(
                  'Roles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    context.read<PolicyManagerBloc>().add(const PolicyManagerLoadingRoles());
                  },
                  tooltip: 'Refresh roles',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<PolicyManagerBloc>().add(const PolicyManagerStartNewRole());
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New Role'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildRolesList(state, context),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesList(PolicyManagerState state, BuildContext context) {
    if (state is PolicyManagerLoading) {
      // If loading state has roles, show them; otherwise show loading spinner
      if (state.roles != null) {
        return _buildLoadedRolesList(state.roles!, context);
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    } else if (state is PolicyManagerError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              'Error: ${state.message}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (state is PolicyManagerLoaded) {
      return _buildLoadedRolesList(state.roles, context);
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildLoadedRolesList(List<Role> roles, BuildContext context) {
    if (roles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No roles found',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: roles.length,
      itemBuilder: (context, index) {
        final role = roles[index];
        return _buildRoleListItem(role, context);
      },
    );
  }

  Widget _buildRoleListItem(Role role, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          role.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          role.description.isEmpty ? 'No description' : role.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          context.read<PolicyManagerBloc>().add(PolicyManagerRoleSelected(role.id ?? ''));
        },
      ),
    );
  }

  Widget _buildMainContent(PolicyManagerState state) {
    if (state is PolicyManagerLoaded && state.selectedRole != null) {
      return PolicyManagerFormView(role: state.selectedRole!);
    }
    
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Select a role to view details',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}