import 'dart:io';

import 'package:material_ui/material_ui.dart';
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
import 'package:noports_config/platform/device_names.dart';
import 'package:noports_config/platform/service_manager.dart';
import 'package:noports_config/styles/app_theme.dart';

/// The points tinashe404 raised on PR #2918, as widget tests: the "@" is
/// supplied for the user, the device name starts as the computer's name,
/// and a finished Keys step is unmistakable.
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
    tmp = Directory.systemTemp.createTempSync('noports_config_fb');
    paths = DaemonPaths.forTest(
      configDir: Directory('${tmp.path}/etc'),
      binDir: Directory('${tmp.path}/bin'),
    );
    DaemonPaths.instance = paths;
    ServiceManager.instance = FakeServiceManager();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Widget app(ConfigCubit config) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => NavCubit()),
      BlocProvider.value(value: config),
      BlocProvider(
        create: (_) => ServiceCubit(
          FakeServiceManager(),
          pollInterval: const Duration(hours: 1),
        ),
      ),
      BlocProvider(
        create: (_) =>
            HealthCubit(paths: paths, services: FakeServiceManager()),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(),
    ),
  );

  Future<ConfigCubit> openWizard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final config = ConfigCubit(
      ConfigRepository(paths: paths, template: () async => template),
    );
    await tester.runAsync(() => config.load());
    await tester.pumpWidget(app(config));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Set up this device for NoPorts'), findsOneWidget);
    return config;
  }

  Future<void> type(WidgetTester tester, Finder f, String text) async {
    var typed = '';
    for (final ch in text.split('')) {
      typed += ch;
      await tester.enterText(f, typed);
      await tester.pump();
    }
  }

  testWidgets('device name starts as this computer\'s name', (tester) async {
    final config = await openWizard(tester);
    expect(config.state.doc!.deviceName, DeviceNames.fromHostname());
    expect(find.text(DeviceNames.fromHostname()), findsWidgets);
    await config.close();
  });

  testWidgets('a bare atsign is stored with its @; a typed @ is dropped', (
    tester,
  ) async {
    final config = await openWizard(tester);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    expect(find.text('@'), findsOneWidget, reason: 'the fixed prefix');

    await type(tester, fields.at(0), 'MyDevice_np');
    await tester.pump(const Duration(milliseconds: 300));
    expect(config.state.doc!.atsign, '@mydevice_np');
    expect(config.state.doc!.source, contains('@mydevice_np'));
    expect(find.text('A device atsign is required.'), findsNothing);

    // Pasting "@other" keeps a single "@": the field strips the typed one.
    await tester.enterText(fields.at(0), '@other');
    await tester.pump(const Duration(milliseconds: 300));
    expect(config.state.doc!.atsign, '@other');
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, 'other');

    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNotNull, reason: 'device step complete');
    await config.close();
  });

  testWidgets('an invalid device name is explained with the daemon rule', (
    tester,
  ) async {
    final config = await openWizard(tester);
    final fields = find.byType(TextField);
    await type(tester, fields.at(0), 'dev');
    await tester.enterText(fields.at(1), 'My-PC');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(DeviceNames.rule), findsOneWidget);
    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNull);
    await tester.tap(find.text("Use this computer's name"));
    await tester.pump(const Duration(milliseconds: 300));
    expect(config.state.doc!.deviceName, DeviceNames.fromHostname());
    expect(find.text(DeviceNames.rule), findsNothing);
    await config.close();
  });

  testWidgets('the Keys step shows a done banner once the keys exist', (
    tester,
  ) async {
    final config = await openWizard(tester);
    final fields = find.byType(TextField);
    await type(tester, fields.at(0), 'dev');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('wizard-keys-ready')), findsNothing);
    expect(find.textContaining('After you click Enroll'), findsOneWidget);
    var next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNull, reason: 'no keys yet');

    // Keys arrive (as enrolling or importing would put them).
    // Synchronous I/O: runAsync here would let the app bar's package_info
    // lookup (no plugin in tests) surface as the test's failure.
    final keys = paths.keysFileFor('@dev');
    keys.parent.createSync(recursive: true);
    keys.writeAsStringSync('{"atsign":"@dev"}');
    config.update((d) => d.keysFile = keys.path);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('wizard-keys-ready')), findsOneWidget);
    expect(
      find.text('@dev is enrolled and its keys are saved on this machine.'),
      findsOneWidget,
    );
    expect(find.textContaining('After you click Enroll'), findsNothing);
    next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNotNull);
    await config.close();
  });
}
