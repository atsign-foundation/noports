import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

/// One profile row in the connections list, backed by the cached [ProfileBloc].
class ProfileListRow extends StatelessWidget {
  final String uuid;
  const ProfileListRow({required this.uuid, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      key: Key("ProfileListView-BlocProvider-$uuid"),
      value: context.read<ProfileCacheCubit>().getProfileBloc(uuid),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: Sizes.p8,
          horizontal: Sizes.p10,
        ),
        child: const ProfileView(),
      ),
    );
  }
}
