import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';

class ProfileListRefreshButton extends StatelessWidget {
  const ProfileListRefreshButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        context.read<ProfileListBloc>().add(const ProfileListLoadEvent());
      },
      child: const Text('Refresh Profiles'),
    );
  }
}
