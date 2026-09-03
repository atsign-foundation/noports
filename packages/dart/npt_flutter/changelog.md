## 1.9.4+31

- FEAT: APKAM enrollment dialog with approval wait and revocation error handling.
- FEAT: Disable sign-in button while atsign activation is in progress.
- FEAT: Revoked enrollment error messaging.
- FEAT: Onboarding error dialog with improved error descriptions.
- FEAT: Authorization features restored (pending enrollment requests).
- FIX: Remove Atsign dialog now scrolls when the atsign list exceeds dialog height.
- FIX: Switching atsigns preserves the current nav bar tab selection.
- FIX: macOS sandbox error when writing .tmp backup key files.
- FIX: File picker and directory picker use correct default paths.
- FIX: OTP error messages surface faster during atsign activation.
- FIX: Enrollment pending requests count bug resolved.
- FIX: Better error messaging in activate_util.dart.
- FIX: profile_repository.dart error handling.
- FIX: settings_action_button layout wrap issue.
- FIX: custom_container.dart layout.
- FIX: file_picker breaking API change adapted.
- FIX: switch_atsign_button.dart uses AuthService directly instead of removed AtOnboarding.
- REFACTOR: Replaced the use of `String` atsign with the `Atsign` class.
- REFACTOR: Where a String atsign is hardcoded or retrieved, `.toAtsign()` is applied.
- REFACTOR: Rename all use of the old 'atSign, AtSign' spelling with new 'atsign, Atsign' spelling.
- REFACTOR: AtOnboardingConfig replaced with direct AuthService calls.
- REFACTOR: PendingRequestsCountCubit uses FlutterEnrollmentService with explicit lifecycle.
- CHORE: Migrate dependencies to at_client_flutter.
- CHORE: Remove at_client_mobile, at_onboarding_flutter, at_contacts, at_contacts_flutter.
- CHORE: Slim down pubspec.yaml dependencies and dev dependencies.
- CHORE: Remove win32 dev dependency (unused).
- CHORE: Override phosphor_flutter with Flutter 3.x compatibility fork.
- CHORE: Updated localization strings.

## 1.9.3+30

-FIX: Back Up Dialog Save button is centered when back button isn't shown.

## 1.9.2+29

-FIX: Activation Dialog Final Title Text changed and Title Icon removed.
-FIX: Back button added to the Save Back Up Dialog.
-FIX: Sign In occurs with the last Atsign in the activation file When Multi-Activation completes.

## 1.9.1+28

- FEAT: windows release automation in GitHub
- CHORE: dart pub get

## 1.9.0+27

- FEAT: Get Started Dialog Added
- FEAT: Sign In Dialog Added
- FEAT: MultiActivation Flow Added
- FIX: Added and Updated descriptions for better clarity along with their language translations.

## 1.8.1+26

- FIX: Backup Key Dialog is shown when user activate an atSign from the get started button.
- FIX: Properly dispose of pin controller and focus node in ActivateAtsignDialog.
- FIX: update error handling for invalid OTP in OnboardingApkamDialog.
- FIX: cursor doesn't jump to the end of the text field unless "@" was auto add to the atsign field.
- FIX: updated and completed localization strings for profile_connect_uri_field strings, removed legacy code.

## 1.8.0+25

- FEAT: App now supports IPv6 and IPv4 numeric entries for local and remote host.
- FIX: Local port and Remote port are aligned correctly.
- FIX: Info SnackBar prefix text now visible.
- FIX: No Error SnackBar is shown when user cancels backing up their key.
- FIX: Policy Screen layout update for better spacing.
- FIX: Standardize widget styles, enhance form validation and improve layout consistency across policy forms.
- FIX: enrollment appName set to `noports` to be consistent with noPorts cli tools.
- FIX: Enrollment Dialog cannot be dismissed once the enrollment process starts
- FIX: Policy and Authorization Screen refreshes after switching atsign.
- FIX: Added a default tool tip to prevent garbled tool tips on the Windows tray Icon
- FEAT: Added auto start of application via URI in configuration of connections
- FEAT: User can Add atsign from the switch atsign button.
- FIX: On Windows the tool tray now has Icons to indicate status (Windows cannot do color in tool tray)
- FIX: In the tool tray now when you click settings you get to the app and the settings page
- FEAT: On Windows clicking the tool tray Icon for a favourite will open the app and connect, if already connected will simply disconnect
- FIX: Updated copyright year to 2026.
- FEAT: Demo Profile uses http as the default protocol.

## 1.7.0+24

- FEAT: App now supports use of atDirectories other than root.atsign.org
- FEAT: App now supports use of atServer proxy services
- FIX: When policy rules are updated in the app, they are now picked up by
  the policy service in near-real-time
- FIX: Policy info being displayed on the policy view is now auto-refreshed
  after an edit has been saved.

## 1.6.4+23

- FIX: policy permit open host and port form validation

## 1.6.3+22

- **FIX**: atSigns are no longer removed from the keychain after an enrollment occurs on windows devices.

## 1.6.2+21

- **CHORE**: Temporarily Removed the policy status light and policy view logs button.

## 1.6.1+20

- **FIX**: Fixed a bug where policy status light timestamping was out of sync

## 1.6.0+19

- **FEAT**: New policy page for policy management and policy logs viewing
- **FEAT**: New app bar
- **FEAT**: New 443 checkbox in dashboard connections profile management which: 1. enables `--443` and 2. inherently forces use of relay ESCR auth mode (so that 443 mode can work).
- **TEST**: Unit and integration tests added.
- **FIX**: Localization added for unlocalized strings.
- **FIX**: Updated onboarding widget to reflect management portal website UI.
- **FIX**: Updated connection screen screen empty profile state UI.
- **FIX**: Moved version number, switch atSign and Sign Out button from settings page to the appbar.
- **FEAT**: Updated Profiles to set localHost property.
- **FIX**: Added export logs to the top right of the onboarding/start screen.
- **FIX**: Renamed "Reset atSign" to "Remove atSign and move it from the bottom right to the top right of the onboarding/start screen.
- **FIX**: Replaced simple and advance preview image from the settings screen.
- **FEAT**: New keep alive checkbox that keeps connection alive
- **FEAT**: Policy status light that indicates whether the policy server is alive or not

## 1.5.0+18

- **FIX**: changed imports for app_localization.dart

## 1.3.0+16

- **FIX**: Prevented MissingPluginException on Windows by calling setVisibleOnAllWorkspaces only on macOS in TrayManager initState
- **FIX**: Version number visible on settings navigation rail by making it scrollable on windows.
- **FIX**: Settings hint message widget removed since a failed profile load is an expected behavior and not a bug.
- **FIX**: authorization icon is now greyed out when it's not available to be pressed on a non-dashboard screen and primary color when app is on the authorization screen.
- **FEAT**: demo profile is downloaded and added to profile screen by pressing the try now button.
- **FEAT**: atSigns can be switched in the settings screen.
- **FIX**: NoPorts logo changed to the correct one.
- **CHORE**: Client atSign changed to NoPorts atSign.

## 1.2.0+15

- **FIX**: Authorization screen
- **FIX**: Backup Key is implemented correctly.
- **FIX**: Added Localization support for the authentication feature.
- **FIX**: Removed current atsign to settings screen side panel.
- **FIX**: Profiles below the deleted profile are now responsive.
- **FIX**: Tooltips messages are centered in the profile columns.
- **FEAT**: Added Version Number on the onboarding and settings screen.
- **FEAT**: New profile can be created by pasting Json and Yaml formatted information.
- **FEAT**: Added current atsign to app bar so it is available on all screens.
- **FEAT**: Profile buttons maintains responsiveness even when profiles are outside the scroll view for hours.

## 1.0.0

- Initial version
