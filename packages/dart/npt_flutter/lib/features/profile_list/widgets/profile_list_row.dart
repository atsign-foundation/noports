import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_drag_handle.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileListRow extends StatelessWidget {
  final String uuid;

  final int? reorderIndex;

  final bool dimmed;
  final bool dragEnabled;

  const ProfileListRow({
    required this.uuid,
    this.reorderIndex,
    this.dimmed = false,
    this.dragEnabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      key: Key("ProfileListView-BlocProvider-$uuid"),
      value: context.read<ProfileCacheCubit>().getProfileBloc(uuid),
      child: AnimatedOpacity(
        opacity: dimmed ? 0.35 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: Sizes.p8,
            horizontal: Sizes.p10,
          ),
          child: Row(
            children: <Widget>[
              ProfileDragHandle(index: reorderIndex, enabled: dragEnabled),
              const Expanded(child: ProfileView()),
            ],
          ),
        ),
      ),
    );
  }
}
