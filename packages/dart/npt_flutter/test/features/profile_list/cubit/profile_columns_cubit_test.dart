import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_list/cubit/profile_columns_cubit.dart';
import 'package:npt_flutter/features/profile_list/models/profile_column.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';

void main() {
  const PreferredViewLayout minimal = PreferredViewLayout.minimal;
  const PreferredViewLayout sshStyle = PreferredViewLayout.sshStyle;

  double total(Map<ProfileColumn, double> widths) {
    return widths.values.fold<double>(0, (double a, double b) => a + b);
  }

  group('ProfileColumn', () {
    test(
      'every column has a minimum of at least the icon button footprint',
      () {
        for (final ProfileColumn column in ProfileColumn.values) {
          expect(
            column.minWidth,
            greaterThanOrEqualTo(kProfileIconColumnWidth),
          );
        }
      },
    );

    test('resizable columns end with status in both layouts', () {
      expect(ProfileColumn.resizableFor(minimal), [
        ProfileColumn.profileName,
        ProfileColumn.status,
      ]);
      expect(ProfileColumn.resizableFor(sshStyle), [
        ProfileColumn.profileName,
        ProfileColumn.deviceName,
        ProfileColumn.serviceMapping,
        ProfileColumn.status,
      ]);
    });

    test('default fractions cover exactly the resizable columns', () {
      for (final PreferredViewLayout layout in PreferredViewLayout.values) {
        final Map<ProfileColumn, double> fractions =
            ProfileColumn.defaultFractionsFor(layout);
        expect(
          fractions.keys.toSet(),
          ProfileColumn.resizableFor(layout).toSet(),
        );
        expect(total(fractions), closeTo(1, 0.000001));
      }
    });
  });

  group('ProfileColumnsState.resolve', () {
    test('fills the available width with the default proportions', () {
      final Map<ProfileColumn, double> widths = ProfileColumnsState.initial()
          .resolve(sshStyle, 1000);

      expect(widths.keys.toList(), ProfileColumn.resizableFor(sshStyle));
      expect(widths[ProfileColumn.profileName], closeTo(240, 0.001));
      expect(widths[ProfileColumn.deviceName], closeTo(240, 0.001));
      expect(widths[ProfileColumn.serviceMapping], closeTo(240, 0.001));
      expect(widths[ProfileColumn.status], closeTo(280, 0.001));
      expect(total(widths), closeTo(1000, 0.001));
    });

    test('splits the minimal layout evenly by default', () {
      final Map<ProfileColumn, double> widths = ProfileColumnsState.initial()
          .resolve(minimal, 600);

      expect(widths[ProfileColumn.profileName], closeTo(300, 0.001));
      expect(widths[ProfileColumn.status], closeTo(300, 0.001));
    });

    test('pins a squeezed column at its minimum and gives the rest away', () {
      const ProfileColumnsState state = ProfileColumnsState({
        minimal: {ProfileColumn.profileName: 0.9, ProfileColumn.status: 0.1},
      });

      final Map<ProfileColumn, double> widths = state.resolve(minimal, 300);

      expect(widths[ProfileColumn.status], ProfileColumn.status.minWidth);
      expect(
        widths[ProfileColumn.profileName],
        closeTo(300 - ProfileColumn.status.minWidth, 0.001),
      );
      expect(total(widths), closeTo(300, 0.001));
    });

    test('pins several columns when more than one is squeezed', () {
      const ProfileColumnsState state = ProfileColumnsState({
        sshStyle: {
          ProfileColumn.profileName: 0.05,
          ProfileColumn.deviceName: 0.05,
          ProfileColumn.serviceMapping: 0.45,
          ProfileColumn.status: 0.45,
        },
      });

      final Map<ProfileColumn, double> widths = state.resolve(sshStyle, 600);

      expect(widths[ProfileColumn.profileName], kProfileTextColumnMinWidth);
      expect(widths[ProfileColumn.deviceName], kProfileTextColumnMinWidth);
      expect(widths[ProfileColumn.serviceMapping], closeTo(220, 0.001));
      expect(widths[ProfileColumn.status], closeTo(220, 0.001));
      expect(total(widths), closeTo(600, 0.001));
    });

    test('returns every minimum when there is not enough room', () {
      final Map<ProfileColumn, double> widths = ProfileColumnsState.initial()
          .resolve(sshStyle, 100);

      for (final ProfileColumn column in ProfileColumn.resizableFor(sshStyle)) {
        expect(widths[column], column.minWidth);
      }
    });

    test(
      'falls back to the defaults for a layout without stored fractions',
      () {
        const ProfileColumnsState state = ProfileColumnsState({});

        final Map<ProfileColumn, double> widths = state.resolve(minimal, 400);

        expect(widths[ProfileColumn.profileName], closeTo(200, 0.001));
        expect(widths[ProfileColumn.status], closeTo(200, 0.001));
      },
    );
  });

  group('ProfileColumnsCubit.resizeColumn', () {
    late ProfileColumnsCubit cubit;

    setUp(() {
      cubit = ProfileColumnsCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test('grows the column and shrinks only the last column', () {
      cubit.resizeColumn(
        layout: sshStyle,
        column: ProfileColumn.profileName,
        width: 300,
        availableWidth: 1000,
      );

      final Map<ProfileColumn, double> widths = cubit.state.resolve(
        sshStyle,
        1000,
      );
      expect(widths[ProfileColumn.profileName], closeTo(300, 0.001));
      expect(widths[ProfileColumn.deviceName], closeTo(240, 0.001));
      expect(widths[ProfileColumn.serviceMapping], closeTo(240, 0.001));
      expect(widths[ProfileColumn.status], closeTo(220, 0.001));
    });

    test('shrinks the column and grows only the last column', () {
      cubit.resizeColumn(
        layout: sshStyle,
        column: ProfileColumn.serviceMapping,
        width: 200,
        availableWidth: 1000,
      );

      final Map<ProfileColumn, double> widths = cubit.state.resolve(
        sshStyle,
        1000,
      );
      expect(widths[ProfileColumn.profileName], closeTo(240, 0.001));
      expect(widths[ProfileColumn.deviceName], closeTo(240, 0.001));
      expect(widths[ProfileColumn.serviceMapping], closeTo(200, 0.001));
      expect(widths[ProfileColumn.status], closeTo(320, 0.001));
    });

    test('never shrinks a column below its minimum', () {
      cubit.resizeColumn(
        layout: minimal,
        column: ProfileColumn.profileName,
        width: 10,
        availableWidth: 600,
      );

      final Map<ProfileColumn, double> widths = cubit.state.resolve(
        minimal,
        600,
      );
      expect(widths[ProfileColumn.profileName], kProfileTextColumnMinWidth);
      expect(
        widths[ProfileColumn.status],
        closeTo(600 - kProfileTextColumnMinWidth, 0.001),
      );
    });

    test('never grows a column past the last column minimum', () {
      cubit.resizeColumn(
        layout: minimal,
        column: ProfileColumn.profileName,
        width: 10000,
        availableWidth: 600,
      );

      final Map<ProfileColumn, double> widths = cubit.state.resolve(
        minimal,
        600,
      );
      expect(widths[ProfileColumn.status], ProfileColumn.status.minWidth);
      expect(
        widths[ProfileColumn.profileName],
        closeTo(600 - ProfileColumn.status.minWidth, 0.001),
      );
    });

    test('ignores the last column and columns outside the layout', () {
      final ProfileColumnsState initial = cubit.state;

      cubit.resizeColumn(
        layout: minimal,
        column: ProfileColumn.status,
        width: 100,
        availableWidth: 600,
      );
      cubit.resizeColumn(
        layout: minimal,
        column: ProfileColumn.deviceName,
        width: 100,
        availableWidth: 600,
      );
      cubit.resizeColumn(
        layout: minimal,
        column: ProfileColumn.favorite,
        width: 100,
        availableWidth: 600,
      );

      expect(cubit.state, initial);
    });

    test('does nothing when there is not enough room to honour minimums', () {
      final ProfileColumnsState initial = cubit.state;

      cubit.resizeColumn(
        layout: sshStyle,
        column: ProfileColumn.profileName,
        width: 300,
        availableWidth: 100,
      );

      expect(cubit.state, initial);
    });

    test('leaves the other layout untouched', () {
      final Map<ProfileColumn, double> before = cubit.state.fractionsFor(
        sshStyle,
      );

      cubit.resizeColumn(
        layout: minimal,
        column: ProfileColumn.profileName,
        width: 400,
        availableWidth: 600,
      );

      expect(cubit.state.fractionsFor(sshStyle), before);
    });

    test('keeps the chosen proportions when the available width changes', () {
      cubit.resizeColumn(
        layout: minimal,
        column: ProfileColumn.profileName,
        width: 400,
        availableWidth: 600,
      );

      final Map<ProfileColumn, double> widths = cubit.state.resolve(
        minimal,
        1200,
      );
      expect(widths[ProfileColumn.profileName], closeTo(800, 0.001));
      expect(widths[ProfileColumn.status], closeTo(400, 0.001));
    });
  });
}
