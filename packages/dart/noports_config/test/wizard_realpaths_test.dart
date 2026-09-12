import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/config/config_repository.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/health/cubit/health_cubit.dart';
import 'package:noports_config/features/service/cubit/service_cubit.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/pages/home_page.dart';
import 'package:noports_config/pages/nav_cubit.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/service_manager.dart';
import 'package:noports_config/styles/app_theme.dart';

class FakeServiceManager extends ServiceManager {
  @override
  String get serviceName => 'sshnpd';
  @override
  String get logSourceDescription => 'fake';
  @override
  Future<ServiceStatus> status() async => const ServiceStatus.notInstalled();
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<String> recentLogs({int lines = 200}) async => '';
  @override
  Future<bool> isElevated() async => true;
}

void main() {
  late Directory tmp;
  late DaemonPaths paths;
  final template = File('assets/sshnpd.template.yaml').readAsStringSync();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('noports_config_widget');
    paths = DaemonPaths.forTest(
      configDir: Directory('${tmp.path}/etc'),
      binDir: Directory('${tmp.path}/bin'),
    );
    // real DaemonPaths on purpose
    ServiceManager.instance = FakeServiceManager();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Widget app(ConfigCubit config) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => NavCubit()),
      BlocProvider.value(value: config),
      BlocProvider(create: (_) => ServiceCubit(FakeServiceManager(), pollInterval: const Duration(hours: 1))),
      BlocProvider(create: (_) => HealthCubit(paths: paths, services: FakeServiceManager())),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(),
    ),
  );

  testWidgets('wizard with real DaemonPaths: typing a bare @ first must not throw', timeout: const Timeout(Duration(seconds: 60)),
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final config = ConfigCubit(ConfigRepository(paths: paths, template: () async => template));
    // Real file I/O must run outside the fake-async zone of testWidgets.
    await tester.runAsync(() => config.load());
    expect(config.state.status, ConfigStatus.ready);
    await tester.pumpWidget(app(config));
    // One frame to build, one for the post-frame wizard decision, one to show it.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Set up this device for NoPorts'), findsOneWidget);
    expect(find.text('A device atSign is required.'), findsOneWidget);

    // Type the way a person does: one key at a time, into each field.
    // (No pumpAndSettle after focusing a TextField: the caret blinks forever.)
    Future<void> type(Finder f, String text) async {
      var typed = '';
      for (final ch in text.split('')) {
        typed += ch;
        await tester.enterText(f, typed);
        await tester.pump();
      }
    }
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2), reason: 'atSign and device name only');
    await type(fields.at(1), 'tarial');
    await type(fields.at(0), '@ssh_1');
    await tester.pump(const Duration(milliseconds: 300));

    expect(config.state.doc!.atsign, '@ssh_1');
    expect(find.text('Set up this device for NoPorts'), findsOneWidget,
        reason: 'wizard must stay open while the user is in it');
    expect(find.text('A device atSign is required.'), findsNothing);

    final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'));
    expect(next.onPressed, isNotNull);
    await config.close();
  });
}
