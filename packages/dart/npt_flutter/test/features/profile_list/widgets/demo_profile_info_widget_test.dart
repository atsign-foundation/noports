import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/profile_list/widgets/demo_profile_info_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';
import 'package:npt_flutter/util/export.dart';

/// An [HttpClient] whose one request is [request].
class _FakeHttpClient extends Fake implements HttpClient {
  _FakeHttpClient(this.request);

  final Future<HttpClientRequest> request;
  bool? closedWithForce;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => request;

  @override
  void close({bool force = false}) => closedWithForce = force;
}

class _FakeRequest extends Fake implements HttpClientRequest {
  _FakeRequest(this.response);

  final HttpClientResponse response;

  @override
  Future<HttpClientResponse> close() async => response;
}

class _FakeResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  _FakeResponse(this.statusCode, String body)
    : super(Stream.value(utf8.encode(body)));

  @override
  final int statusCode;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A [ProfileListBloc] that records what it is sent instead of handling it.
class _RecordingProfileListBloc extends ProfileListBloc {
  _RecordingProfileListBloc() : super(ProfileRepository());

  final events = <ProfileListEvent>[];

  @override
  void add(ProfileListEvent event) => events.add(event);
}

final _strings = AppLocalizationsEn();

Finder _snackBarText(String text) =>
    find.textContaining(text, findRichText: true);

void main() {
  late _RecordingProfileListBloc profileList;

  setUp(() => profileList = _RecordingProfileListBloc());

  /// Shows the demo widget, taps it with [client] serving the download, and
  /// runs [whilePending] while the progress indicator is up.
  Future<void> tapDemo(
    WidgetTester tester,
    _FakeHttpClient client, {
    required Future<void> Function() whilePending,
  }) async {
    tester.view.physicalSize = const Size(2400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => EnableLoggingCubit()),
            BlocProvider(create: (_) => LogsCubit()),
            BlocProvider<ProfileListBloc>.value(value: profileList),
          ],
          child: MaterialApp(
            navigatorKey: App.navState,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DemoProfileInfoWidget()),
          ),
        ),
      );

      await tester.tap(find.text(_strings.demoTextButton));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await whilePending();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }, createHttpClient: (_) => client);
  }

  testWidgets('a failed connection dismisses the progress indicator and says '
      'the import failed', (tester) async {
    final request = Completer<HttpClientRequest>();
    final client = _FakeHttpClient(request.future);

    await tapDemo(
      tester,
      client,
      whilePending: () async =>
          request.completeError(const SocketException('offline')),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_snackBarText(_strings.profileImportFailed), findsOneWidget);
    expect(client.closedWithForce, isTrue);
    expect(profileList.events, isEmpty);
  });

  testWidgets('a refused download dismisses the progress indicator and says '
      'the import failed', (tester) async {
    final request = Completer<HttpClientRequest>();
    final client = _FakeHttpClient(request.future);

    await tapDemo(
      tester,
      client,
      whilePending: () async =>
          request.complete(_FakeRequest(_FakeResponse(404, 'Not Found'))),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_snackBarText(_strings.profileImportFailed), findsOneWidget);
    expect(client.closedWithForce, isTrue);
    expect(profileList.events, isEmpty);
  });

  testWidgets('a stalled download gives up after the timeout', (tester) async {
    final client = _FakeHttpClient(Completer<HttpClientRequest>().future);

    await tapDemo(
      tester,
      client,
      whilePending: () async {
        await tester.pump(
          Export.demoProfileTimeout - const Duration(seconds: 1),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
      },
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_snackBarText(_strings.profileImportFailed), findsOneWidget);
    expect(client.closedWithForce, isTrue);
  });

  testWidgets('a downloaded profile is imported', (tester) async {
    final request = Completer<HttpClientRequest>();
    final client = _FakeHttpClient(request.future);

    await tapDemo(
      tester,
      client,
      whilePending: () async => request.complete(
        _FakeRequest(_FakeResponse(200, '{"profiles": []}')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(profileList.events, [isA<ProfileListAddEvent>()]);
    expect(_snackBarText(_strings.profileImportFailed), findsNothing);
    expect(_snackBarText(_strings.fileImported), findsOneWidget);
  });
}
