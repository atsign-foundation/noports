part of 'profile_columns_cubit.dart';

final class ProfileColumnsState extends Equatable {
  const ProfileColumnsState(this.fractions);

  factory ProfileColumnsState.initial() {
    return ProfileColumnsState({
      for (final PreferredViewLayout layout in PreferredViewLayout.values)
        layout: ProfileColumn.defaultFractionsFor(layout),
    });
  }

  final Map<PreferredViewLayout, Map<ProfileColumn, double>> fractions;

  Map<ProfileColumn, double> fractionsFor(PreferredViewLayout layout) {
    return fractions[layout] ?? ProfileColumn.defaultFractionsFor(layout);
  }

  Map<ProfileColumn, double> resolve(
    PreferredViewLayout layout,
    double availableWidth,
  ) {
    final List<ProfileColumn> columns = ProfileColumn.resizableFor(layout);
    final Map<ProfileColumn, double> layoutFractions = fractionsFor(layout);
    final double minimumTotal = columns.fold<double>(
      0,
      (double sum, ProfileColumn column) => sum + column.minWidth,
    );

    if (availableWidth <= minimumTotal) {
      return {
        for (final ProfileColumn column in columns) column: column.minWidth,
      };
    }

    final Map<ProfileColumn, double> pinned = {};
    List<ProfileColumn> flexible = List<ProfileColumn>.of(columns);
    while (flexible.isNotEmpty) {
      final double pinnedTotal = pinned.values.fold<double>(
        0,
        (double a, double b) => a + b,
      );
      final double remaining = availableWidth - pinnedTotal;
      final double fractionTotal = flexible.fold<double>(
        0,
        (double sum, ProfileColumn column) =>
            sum + (layoutFractions[column] ?? 0),
      );
      final Map<ProfileColumn, double> proposed = {
        for (final ProfileColumn column in flexible)
          column: fractionTotal > 0
              ? remaining * (layoutFractions[column] ?? 0) / fractionTotal
              : remaining / flexible.length,
      };
      final List<ProfileColumn> underMinimum = flexible
          .where((ProfileColumn column) => proposed[column]! < column.minWidth)
          .toList();
      if (underMinimum.isEmpty) {
        return {
          for (final ProfileColumn column in columns)
            column: pinned[column] ?? proposed[column]!,
        };
      }
      for (final ProfileColumn column in underMinimum) {
        pinned[column] = column.minWidth;
      }
      flexible = flexible
          .where((ProfileColumn column) => !pinned.containsKey(column))
          .toList();
    }
    return {
      for (final ProfileColumn column in columns) column: pinned[column]!,
    };
  }

  @override
  List<Object?> get props => [fractions];
}
