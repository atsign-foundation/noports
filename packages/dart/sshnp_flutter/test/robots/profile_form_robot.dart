import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noports_core/sshnp.dart';
import 'package:sshnp_flutter/src/controllers/config_controller.dart';
import 'package:sshnp_flutter/src/presentation/screens/profile_editor_screen.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/custom_switch_widget.dart';

import 'mocks.dart';

class ProfileFormRobot {
  ProfileFormRobot(this.tester);

  final WidgetTester tester;

  Future<void> pumpProfileForm(
      {ConfigListController? mockConfigListController, MockConfigFamilyController? mockConfigFamilyController}) async {
    await tester.pumpWidget(const ProviderScope(
        overrides: [
          // if (mockConfigListController != null)
          //   configListController.overrideWith(() => mockConfigListController),
          // if (mockConfigFamilyController != null)
          //   atSSHKeyPairFamilyController
          //       .overrideWith(() => mockConfigFamilyController)
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileEditorScreen(),
        )));
  }

  void findCircularProgressIndicator() {
    final finder = find.byType(CircularProgressIndicator);
    expect(finder, findsOneWidget);
  }

  void findProfileFormWidgetsWithDefaultValues({required SshnpParams configFile}) async {
    // 6 widgets of type TextFormField have empty text
    expect(find.widgetWithText(TextFormField, ''), findsNWidgets(6));

    // 2 widget of type switch have false value
    expect(find.byWidgetPredicate((widget) => widget is Switch && widget.value == false), findsNWidgets(2));

    // ProfileName
    final profileNameFinder = find.text('Profile Name');

    expect(profileNameFinder, findsOneWidget);

    // DeviceName
    final deviceNameFinder = find.text('Device Name');
    expect(deviceNameFinder, findsOneWidget);

    final deviceAddressFinder = find.text('Device Address');
    expect(deviceAddressFinder, findsOneWidget);

    // Host
    final hostFinder = find.text('Host');
    expect(hostFinder, findsOneWidget);

    // SSH Public Key
    final sshPublicKeyFinder = find.text('SSH Public Key');
    expect(sshPublicKeyFinder, findsOneWidget);

    // Legacy RSA Key
    final legacyRSAKeyTextFinder = find.text('Legacy RSA Key');
    expect(legacyRSAKeyTextFinder, findsOneWidget);

    // Remote Username
    final remoteUsernameFinder = find.text('Remote Username');
    expect(remoteUsernameFinder, findsOneWidget);

    // Remote Port
    // remote port and local sshd port has the same default value
    final remotePortFinder = find.text('Remote Port');
    expect(remotePortFinder, findsOneWidget);
    expect(find.text(configFile.remoteSshdPort.toString()), findsNWidgets(2));

    // Local Port
    final localPortFinder = find.text('Local Port');
    expect(localPortFinder, findsOneWidget);
    expect(find.text(configFile.localPort.toString()), findsOneWidget);

    // Local SSH options
    final localSSHOptionsFinder = find.text('Local SSH Options');
    expect(localSSHOptionsFinder, findsOneWidget);

    // atKeys File
    final atKeysFileFinder = find.text('atKeys File');
    expect(atKeysFileFinder, findsOneWidget);
    expect(find.text(configFile.atKeysFilePath!), findsOneWidget);

    // Root Domain
    final rootDomainFinder = find.text('Root Domain');
    expect(rootDomainFinder, findsOneWidget);
    expect(find.text(configFile.rootDomain), findsOneWidget);

    // Verbose Logging
    final verboseLoggingFinder = find.text('Verbose Logging');
    expect(verboseLoggingFinder, findsOneWidget);
  }

  void findProfileFormWidgetsWithNewValues() async {
    // ProfileName
    final profileNameFinder = find.widgetWithText(TextFormField, 'Profile Name');
    await tester.enterText(profileNameFinder, 'test profile');
    expect(find.text('test profile'), findsOneWidget);

    // DeviceName
    final deviceNameFinder = find.widgetWithText(TextFormField, 'Device Name');
    await tester.enterText(deviceNameFinder, 'test device');
    expect(find.text('test device'), findsOneWidget);

    // Device Address
    final deviceAddressFinder = find.widgetWithText(TextFormField, 'Device Address');
    await tester.enterText(deviceAddressFinder, 'test address');
    expect(find.text('test address'), findsOneWidget);

    // Host
    final hostFinder = find.widgetWithText(TextFormField, 'Host');
    await tester.enterText(hostFinder, 'test host');
    expect(find.text('test host'), findsOneWidget);

    // SSH Public Key
    final sshPublicKeyFinder = find.widgetWithText(TextFormField, 'SSH Public Key');
    await tester.enterText(sshPublicKeyFinder, 'test public key');
    expect(find.text('test public key'), findsOneWidget);

    // Legacy RSA Key
    final legacyRSAKeyTextFinder = find.text('Legacy RSA Key');
    expect(legacyRSAKeyTextFinder, findsOneWidget);
    // Legacy RSA Key is the first switch
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(
        find.byWidgetPredicate(
            (widget) => widget is CustomSwitchWidget && widget.value == true && widget.labelText == 'Legacy RSA Key'),
        findsOneWidget);

    // Remote Username
    final remoteUsernameFinder = find.widgetWithText(TextFormField, 'Remote Username');
    await tester.enterText(remoteUsernameFinder, 'test remote username');
    expect(find.text('test remote username'), findsOneWidget);

    // Remote Port
    final remotePortFinder = find.widgetWithText(TextFormField, 'Remote Port');
    await tester.enterText(remotePortFinder, 'test remote port');
    expect(find.text('test remote port'), findsOneWidget);

    // Local Port
    final localPortFinder = find.widgetWithText(TextFormField, 'Local Port');
    await tester.enterText(localPortFinder, 'test local port');
    expect(find.text('test local port'), findsOneWidget);

    // Local SSH options
    final localSSHOptionsFinder = find.widgetWithText(TextFormField, 'Local SSH Options');
    await tester.enterText(localSSHOptionsFinder, 'test local ssh options');
    expect(find.text('test local ssh options'), findsOneWidget);

    // atKeys File
    final atKeysFileFinder = find.widgetWithText(TextFormField, 'atKeys File');
    await tester.enterText(atKeysFileFinder, 'test atKeys File');
    expect(find.text('test atKeys File'), findsOneWidget);

    // Root Domain
    final rootDomainFinder = find.widgetWithText(TextFormField, 'Root Domain');
    await tester.enterText(rootDomainFinder, 'test root domain');
    expect(find.text('test root domain'), findsOneWidget);

    // Verbose Logging
    // verbose logging is the last switch
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    expect(
        find.byWidgetPredicate(
            (widget) => widget is CustomSwitchWidget && widget.value == true && widget.labelText == 'Verbose Logging'),
        findsOneWidget);
  }

  void submitFormWithValues() async {
    // ProfileName
    final profileNameFinder = find.widgetWithText(TextFormField, 'Profile Name');
    await tester.enterText(profileNameFinder, 'test profile');
    expect(find.text('test profile'), findsOneWidget);

    // DeviceName
    final deviceNameFinder = find.widgetWithText(TextFormField, 'Device Name');
    await tester.enterText(deviceNameFinder, 'test device');
    expect(find.text('test device'), findsOneWidget);

    // Device Address
    final deviceAddressFinder = find.widgetWithText(TextFormField, 'Device Address');
    await tester.enterText(deviceAddressFinder, 'test address');
    expect(find.text('test address'), findsOneWidget);

    // Host
    final hostFinder = find.widgetWithText(TextFormField, 'Host');
    await tester.enterText(hostFinder, 'test host');
    expect(find.text('test host'), findsOneWidget);

    // SSH Public Key
    final sshPublicKeyFinder = find.widgetWithText(TextFormField, 'SSH Public Key');
    await tester.enterText(sshPublicKeyFinder, 'test public key');
    expect(find.text('test public key'), findsOneWidget);

    // Legacy RSA Key
    final legacyRSAKeyTextFinder = find.text('Legacy RSA Key');
    expect(legacyRSAKeyTextFinder, findsOneWidget);
    // Legacy RSA Key is the first switch
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(
        find.byWidgetPredicate(
            (widget) => widget is CustomSwitchWidget && widget.value == true && widget.labelText == 'Legacy RSA Key'),
        findsOneWidget);

    // Remote Username
    final remoteUsernameFinder = find.widgetWithText(TextFormField, 'Remote Username');
    await tester.enterText(remoteUsernameFinder, 'test remote username');
    expect(find.text('test remote username'), findsOneWidget);

    // Remote Port
    final remotePortFinder = find.widgetWithText(TextFormField, 'Remote Port');
    await tester.enterText(remotePortFinder, 'test remote port');
    expect(find.text('test remote port'), findsOneWidget);

    // Local Port
    final localPortFinder = find.widgetWithText(TextFormField, 'Local Port');
    await tester.enterText(localPortFinder, 'test local port');
    expect(find.text('test local port'), findsOneWidget);

    // Local SSH options
    final localSSHOptionsFinder = find.widgetWithText(TextFormField, 'Local SSH Options');
    await tester.enterText(localSSHOptionsFinder, 'test local ssh options');
    expect(find.text('test local ssh options'), findsOneWidget);

    // atKeys File
    final atKeysFileFinder = find.widgetWithText(TextFormField, 'atKeys File');
    await tester.enterText(atKeysFileFinder, 'test atKeys File');
    expect(find.text('test atKeys File'), findsOneWidget);

    // Root Domain
    final rootDomainFinder = find.widgetWithText(TextFormField, 'Root Domain');
    await tester.enterText(rootDomainFinder, 'test root domain');
    expect(find.text('test root domain'), findsOneWidget);

    // Verbose Logging
    // verbose logging is the last switch
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    expect(
        find.byWidgetPredicate(
            (widget) => widget is CustomSwitchWidget && widget.value == true && widget.labelText == 'Verbose Logging'),
        findsOneWidget);

    // Submit the form
    final submitButtonFinder = find.text('Submit');
    await tester.tap(submitButtonFinder);
    await tester.pump();
    debugDumpApp();
    expect(find.text('Available Connections'), findsOneWidget);
  }
}
