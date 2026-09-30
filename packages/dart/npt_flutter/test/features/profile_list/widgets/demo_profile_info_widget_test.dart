import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_list/widgets/demo_profile_info_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';

/// An [HttpClient] whose one request fails when the test says so.
class _PendingHttpClient extends Fake implements HttpClient {
  final Completer<HttpClientRequest> request = Completer();
  bool closed = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => request.future;

  @override
  void close({bool force = false}) => closed = true;
}

void main() {
  testWidgets('a failed download dismisses the progress indicator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _PendingHttpClient();

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DemoProfileInfoWidget()),
        ),
      );

      await tester.tap(find.text(AppLocalizationsEn().demoTextButton));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      client.request.completeError(const SocketException('offline'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }, createHttpClient: (_) => client);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(client.closed, isTrue);
  });
}
