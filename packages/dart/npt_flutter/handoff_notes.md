# Handoff Notes — npt_flutter

## Summary
This branch is mainly an SDK migration for the Flutter app. The work moves the package away from older onboarding and authorization packages toward the newer at_client_flutter-based flow and updates related UI and utility code.

## What changed
- Migrated onboarding and authorization-related code from legacy package imports to at_client_flutter-based APIs.
- Updated authorization flow wiring to use FlutterEnrollmentService-style handling rather than the older authorization service approach.
- Refactored onboarding utilities and dialogs so the app uses direct AtClientPreference-based onboarding behavior instead of the older onboarding wrapper pattern.
- Updated backup-key flow to the new SDK path, although some parts are still marked as TODO/untested.
- Updated dependency declarations in [pubspec.yaml](pubspec.yaml) and [pubspec.lock](pubspec.lock), and refreshed generated plugin registration files for macOS, Linux, and Windows.
- Adjusted several supporting widgets and helpers in profile, settings, policy, and relay-related areas.

## Why this was changed
The goal was to bring the app in line with the newer at_client_flutter SDK and remove dependency on older packages such as at_client_mobile and at_onboarding_flutter.

## Key files to review first
- [lib/features/onboarding/util/onboarding_util.dart](lib/features/onboarding/util/onboarding_util.dart)
- [lib/features/onboarding/util/activate_util.dart](lib/features/onboarding/util/activate_util.dart)
- [lib/features/onboarding/widgets/activate_atsign_dialog.dart](lib/features/onboarding/widgets/activate_atsign_dialog.dart)
- [lib/features/onboarding/cubit/multi_activation_cubit.dart](lib/features/onboarding/cubit/multi_activation_cubit.dart)
- [lib/features/authorisation/view/authorisation_view.dart](lib/features/authorisation/view/authorisation_view.dart)
- [lib/features/onboarding/util/atsign_manager.dart](lib/features/onboarding/util/atsign_manager.dart)
- [pubspec.yaml](pubspec.yaml)

## Important caveats
- Some onboarding and backup-key paths were migrated but still need follow-up verification.
- The migration plan in [at_client_flutter_migration_plan.md](at_client_flutter_migration_plan.md) explicitly calls out remaining work and TODOs for backup-key and activation-related areas.
- The current branch includes a number of test updates, but some of the refactored onboarding and authorization paths are still not fully covered by tests.

## Recommended verification
- Run the app and exercise onboarding, activation, authorization, profile, policy, and settings flows.
- Re-run the relevant widget/unit tests.
- Pay extra attention to backup-key export, multi-activation, and authorization approval/denial behavior.

## Current repo state
The repository currently shows additional modified files beyond the latest committed tip. These pending changes have now been collected into a single handoff commit so the next developer receives the complete state of the work in one place.
