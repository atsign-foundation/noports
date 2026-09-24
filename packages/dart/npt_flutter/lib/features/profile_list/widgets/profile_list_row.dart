import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_drag_handle.dart';
import 'package:npt_flutter/styles/sizes.dart';

/// One profile row in the connections list, backed by the cached [ProfileBloc].
class ProfileListRow extends StatelessWidget {
  final String uuid;

  /// Index in the enclosing reorderable list, or null if it can't be dragged.
  final int? reorderIndex;

  final bool dimmed;

  const ProfileListRow({
    required this.uuid,
    this.reorderIndex,
    this.dimmed = false,
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
              ProfileDragHandle(index: reorderIndex),
              const Expanded(child: ProfileView()),
            ],
          ),
        ),
      ),
    );
  }
}
