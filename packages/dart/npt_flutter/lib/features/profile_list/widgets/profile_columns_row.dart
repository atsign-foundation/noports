import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/cubit/profile_columns_cubit.dart';
import 'package:npt_flutter/features/profile_list/models/profile_column.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';

typedef ProfileColumnCellBuilder =
    Widget Function(ProfileColumn column, double width);
typedef ProfileColumnDividerBuilder =
    Widget Function(ProfileColumn column, double width, double availableWidth);

const Widget _columnGap = SizedBox(width: kProfileColumnGap);

class ProfileColumnsRow extends StatelessWidget {
  const ProfileColumnsRow({
    super.key,
    required this.layout,
    required this.select,
    required this.cellBuilder,
    required this.favorite,
    required this.menu,
    this.dividerBuilder,
  });

  final PreferredViewLayout layout;
  final Widget select;
  final ProfileColumnCellBuilder cellBuilder;
  final Widget favorite;
  final Widget menu;
  final ProfileColumnDividerBuilder? dividerBuilder;

  @override
  Widget build(BuildContext context) {
    final List<ProfileColumn> columns = ProfileColumn.resizableFor(layout);
    return Row(
      children: [
        SizedBox(width: ProfileColumn.select.minWidth, child: select),
        _columnGap,
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double availableWidth =
                  constraints.maxWidth -
                  kProfileColumnGap * (columns.length - 1);
              return BlocBuilder<ProfileColumnsCubit, ProfileColumnsState>(
                builder: (BuildContext context, ProfileColumnsState state) {
                  final Map<ProfileColumn, double> widths = state.resolve(
                    layout,
                    availableWidth,
                  );
                  final List<Widget> children = [];
                  for (int i = 0; i < columns.length; i++) {
                    final ProfileColumn column = columns[i];
                    final double width = widths[column]!;
                    children.add(
                      SizedBox(width: width, child: cellBuilder(column, width)),
                    );
                    if (i < columns.length - 1) {
                      children.add(
                        dividerBuilder?.call(column, width, availableWidth) ??
                            _columnGap,
                      );
                    }
                  }
                  return UnconstrainedBox(
                    constrainedAxis: Axis.vertical,
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.hardEdge,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  );
                },
              );
            },
          ),
        ),
        _columnGap,
        SizedBox(width: ProfileColumn.favorite.minWidth, child: favorite),
        _columnGap,
        SizedBox(width: ProfileColumn.menu.minWidth, child: menu),
        _columnGap,
      ],
    );
  }
}
