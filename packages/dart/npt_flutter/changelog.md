## 1.6.0+19

- **FEAT**: New policy page for policy management and policy logs viewing
- **FEAT**: New app bar
- **FEAT**: New 443 checkbox in dashboard connections profile management which: 1. enables `--443` and 2. inherently forces use of relay ESCR auth mode (so that 443 mode can work)
- **TEST**: Unit and integration tests added.
- **FIX**: Localization added for unlocalized strings.
- **FIX**: Updated onboarding widget to reflect management portal website UI.
- **FIX**: Updated connection screen screen empty profile state UI.
- **FIX**: Moved version number & switch atsign button from settings page to the appbar.

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
