import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/models/profile_column.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';

part 'profile_columns_state.dart';

class ProfileColumnsCubit extends Cubit<ProfileColumnsState> {
  ProfileColumnsCubit() : super(ProfileColumnsState.initial());

  void resizeColumn({
    required PreferredViewLayout layout,
    required ProfileColumn column,
    required double width,
    required double availableWidth,
  }) {
    final List<ProfileColumn> columns = ProfileColumn.resizableFor(layout);
    final ProfileColumn last = columns.last;
    if (column == last || !columns.contains(column)) return;

    final Map<ProfileColumn, double> widths = Map<ProfileColumn, double>.of(
      state.resolve(layout, availableWidth),
    );
    final double current = widths[column]!;
    final double maxWidth = math.max(
      column.minWidth,
      current + (widths[last]! - last.minWidth),
    );
    final double next = math.min(math.max(width, column.minWidth), maxWidth);
    final double delta = next - current;
    if (delta == 0) return;

    widths[column] = next;
    widths[last] = widths[last]! - delta;

    final double total = widths.values.fold<double>(0, (a, b) => a + b);
    emit(
      ProfileColumnsState({
        ...state.fractions,
        layout: {
          for (final MapEntry<ProfileColumn, double> entry in widths.entries)
            entry.key: entry.value / total,
        },
      }),
    );
  }
}
