import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';

class ProfileListRefreshButton extends StatelessWidget {
  final bool useCache;
  const ProfileListRefreshButton({super.key, this.useCache = false});

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
