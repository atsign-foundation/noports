import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileHeaderColumn extends StatelessWidget {
  const ProfileHeaderColumn({
    super.key,
    required this.title,
    required this.column,
    required this.currentSortColumn,
    required this.sortOrder,
    required this.width,
  });

  final String title;

  /// The column this header represents
  final SortColumn column;

  /// The current sort column the profile list is sorted by
  final SortColumn currentSortColumn;
  final SortOrder sortOrder;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isActive = column == currentSortColumn;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () {
          context.read<ProfileListBloc>().add(
            ProfileListSortEvent(sortColumn: column),
          );
        },
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            gapW4,
            if (isActive)
              Icon(
                sortOrder == SortOrder.ascending
                    ? PhosphorIcons.caretUp()
                    : PhosphorIcons.caretDown(),
              ),
          ],
        ),
      ),
    );
  }
}
