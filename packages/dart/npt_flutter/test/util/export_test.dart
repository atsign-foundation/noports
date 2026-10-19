import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';
import 'package:npt_flutter/util/export.dart';

final _strings = AppLocalizationsEn();

Finder _snackBarText(String text) =>
    find.textContaining(text, findRichText: true);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('npt_export_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EnableLoggingCubit()),
        BlocProvider(create: (_) => LogsCubit()),
      ],
      child: MaterialApp(
        navigatorKey: App.navState,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );

  Future<void> save(
    WidgetTester tester,
    Future<File?> Function(ExportableProfileFiletype) pickFile,
  ) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => Export.saveFile(ExportableProfileFiletype.json, [
        {'name': 'lab'},
      ], pickFile: pickFile),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the export is written and then said to be saved', (
    tester,
  ) async {
    final file = File('${dir.path}/export.json');

    await save(tester, (_) async => file);

    expect(file.readAsStringSync(), '{"profiles":[{"name":"lab"}]}');
    expect(_snackBarText(_strings.fileSaved), findsOneWidget);
    expect(_snackBarText(_strings.fileSaveFailed), findsNothing);
  });

  testWidgets('a failed write says the file was not saved', (tester) async {
    // A directory can't be written as a file.
    await save(tester, (_) async => File(dir.path));

    expect(_snackBarText(_strings.fileSaveFailed), findsOneWidget);
    expect(_snackBarText(_strings.fileSaved), findsNothing);
  });

  testWidgets('a failed pick says the file was not saved', (tester) async {
    await save(
      tester,
      (_) async => throw const FileSystemException('no permission'),
    );

    expect(_snackBarText(_strings.fileSaveFailed), findsOneWidget);
    expect(_snackBarText(_strings.fileSaved), findsNothing);
  });

  testWidgets('a cancelled pick says nothing', (tester) async {
    await save(tester, (_) async => null);

    expect(_snackBarText(_strings.fileSaveFailed), findsNothing);
    expect(_snackBarText(_strings.fileSaved), findsNothing);
  });
}
