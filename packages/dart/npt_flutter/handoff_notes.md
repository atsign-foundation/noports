# Handoff Notes — npt_flutter (`2554-npt_flutter_update` branch)

**Branch:** `2554-npt_flutter_update`
**Base:** `trunk` @ `b895f728de35ee8be49551ad6dc89330ab89765b`
**State:** All work described below is committed. `git status` is clean as of this handoff.

## 1. Goal

Migrate `npt_flutter` off the legacy at-sign SDK packages and onto `at_client_flutter`:

- Remove `at_client_mobile`
- Remove `at_onboarding_flutter`
- Remove `at_backupkey_flutter`
- Rebuild auth/onboarding/enrollment/backup-key flows on top of `at_client_flutter` + `at_auth` APIs

The full design/migration plan (with a legacy→new API mapping table) lives in [at_client_flutter_migration_plan.md](at_client_flutter_migration_plan.md). Read that file for the "why" behind each API swap — this document focuses on the concrete "what changed" for this branch.

## 2. Dependency changes ([pubspec.yaml](pubspec.yaml))

- Removed: `at_client_mobile`, `at_onboarding_flutter` (git dependency), `at_backupkey_flutter`
- Added: `at_client_flutter: ^1.1.1`
- Bumped: `at_auth` (2.4.0 → 3.1.0), `at_utils`, `at_contacts_flutter`, `device_info_plus`, `file_picker` (10.x → 11.x), `flutter_bloc` (8.x → 9.x), `flutter_dotenv`, `package_info_plus`, `pin_code_fields` (8.x → 9.x), `toml`, `window_manager`, `bloc_test` (9.x → 10.x)
- `dependency_overrides` cleaned up: removed the old git overrides for `at_onboarding_flutter`/`at_client_mobile` (left commented out for reference), added `at_commons`, `at_cli_commons`, bumped `at_onboarding_cli`
- App version bumped 1.9.3+30 → 1.9.4+31
- Generated plugin registrant files (`linux/flutter/generated_plugin_registrant.cc`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `windows/flutter/generated_plugin_registrant.cc`, and the `generated_plugins.cmake` files) were regenerated as a side effect of the dependency change — no manual edits needed, but if you run `flutter pub get` these may regenerate again and diff slightly.

**Action for next dev:** run `flutter pub get` and confirm `pubspec.lock` resolves cleanly before doing anything else.

## 3. Authorization / enrollment flow

- [lib/app.dart](lib/app.dart): `AuthorisationService` → `FlutterEnrollmentService`, provided the same way via `RepositoryProvider`. Also removed the `AtClientMobileLocalizations.delegate` from `localizationsDelegates` (left a `TODO` — there's no `at_client_flutter` localization delegate yet).
- [lib/features/authorisation/cubit/pending_requests_count_cubit.dart](lib/features/authorisation/cubit/pending_requests_count_cubit.dart): now builds an `AtLookupImpl` manually from the current `AtClient`'s prefs and calls `FlutterEnrollmentService.list([EnrollmentStatus.pending], atLookUp)` instead of the old `getEnrollmentRequests(statusFilters: ...)`. The `AtLookupImpl` is closed in a `finally` block after each call — this pattern is repeated elsewhere and should stay consistent if it's touched again.
- [lib/features/authorisation/view/authorisation_view.dart](lib/features/authorisation/view/authorisation_view.dart): `AuthorisationHub` widget replaced with `EnrollmentRequestList` (no `service`/`themeData` props needed — it manages its own subscription and theme now).
- [lib/features/onboarding/util/post_onboard.dart](lib/features/onboarding/util/post_onboard.dart) / [pre_offboard.dart](lib/features/onboarding/util/pre_offboard.dart): `AuthorisationService.init()` call removed (no longer needed — the cubit subscribes in its own constructor); `AuthorisationService.dispose()` → `FlutterEnrollmentService.dispose()`.

## 4. Onboarding core rewrite ([lib/features/onboarding/util/onboarding_util.dart](lib/features/onboarding/util/onboarding_util.dart))

This file had the largest logic change (~420 lines touched). Key points for whoever picks this up:

- **New result type:** added [lib/features/onboarding/models/onboard_result.dart](lib/features/onboarding/models/onboard_result.dart) — a sealed class `OnboardResult` with `OnboardSuccess(atsign, enrollmentId?)`, `OnboardCancelled()`, `OnboardError(message)`. This replaces the old `AtOnboardingResult` / `AtOnboardingResultStatus` everywhere. All callers now switch on this sealed type (Dart pattern matching), e.g. in `onboard()` and in [switch_atsign_button.dart](lib/widgets/switch_atsign_button.dart).
- **New shared init helper:** `initializeAfterAuth({atsign, rootDomain, atClientPreference, enrollmentId})` at the top of `onboarding_util.dart` centralizes what used to be duplicated inline in multiple places (set current atsign, init contacts service, add sync progress listener, kick off sync, call `postOnboard`, save atsign info, push backup-key status). Both `onboard()` and `switch_atsign_button.dart`'s `_handleAddAtsign`/`_performOnboarding` now call this shared function — **do not re-duplicate this logic if you touch onboarding again.**
- **CRAM activation flow** (`_handleActivation`, for `unavailable`/`teapot` atsigns): previously showed a custom `ActivateAtsignDialog` backed by `ActivateUtil`. Now uses `RegistrarCramDialog.show(context, request, registrar: RegistrarService(...))` to get a CRAM key, then calls `AuthService().onboard(request, cramKey)`.
- **Already-activated atsign flow** (`_handleActivatedAtsign`): the atKeys-file-upload path now uses `AtKeysFileDialog.show(context)` + `PkamDialog.show(context, request: AtAuthRequest(...))` instead of the old `uploadAtKeysFile()` stream + big switch statement handling `FileUploadStatus` variants (`ErrorIncorrectKeyFile`, `ErrorAtSignMismatch`, etc. — that whole `_handleFileUploadStatusStream` method and the `onProgress` callback plumbing were deleted).
- **Keychain-based re-auth** (`onboard()` when atsign already in keychain): now uses `PkamDialog.show(context, request: AtAuthRequest(atsign, atKeysIo: KeychainAtKeysIo(), ...))` instead of `AtOnboarding.onboard(...)`.
- `KeyChainManager.getInstance().getAtSignListFromKeychain()` → `KeychainStorage().getAllAtsigns()` (also changed in [atsign_manager.dart](lib/features/onboarding/util/atsign_manager.dart) and [switch_atsign_button.dart](lib/widgets/switch_atsign_button.dart)).

### Dead code left behind — needs deletion

These two files are **no longer imported or referenced anywhere** in `lib/` (confirmed via grep) now that `RegistrarCramDialog` handles CRAM activation directly:

- [lib/features/onboarding/util/activate_util.dart](lib/features/onboarding/util/activate_util.dart)
- [lib/features/onboarding/widgets/activate_atsign_dialog.dart](lib/features/onboarding/widgets/activate_atsign_dialog.dart)

The migration plan already flags these for deletion "once `RegistrarCramDialog` is in place" — that's now done, so **the next step is to delete these two files** (and their associated tests, if any) and run `dart analyze` to confirm nothing else references them.

## 5. Multi-activation flow ([lib/features/onboarding/cubit/multi_activation_cubit.dart](lib/features/onboarding/cubit/multi_activation_cubit.dart))

- `FilePicker.platform.pickFiles(...)` / `.getDirectoryPath(...)` → static `FilePicker.pickFiles(...)` / `FilePicker.getDirectoryPath(...)` (API shape changed in `file_picker` 11.x — same change applied in [lib/util/export.dart](lib/util/export.dart) and [backup_key_repository.dart](lib/features/back_up_key/repository/backup_key_repository.dart)).
- `OnboardingService.getInstance().onboard(...)` → `AuthService().onboard(onboardingRequest, cramSecret)`, checking `response.isSuccessful` instead of a `bool success`.
- **Left in a half-finished state, marked with an explicit TODO in the code:** the block that used to call `onboardingService.setAtsign = atsign` and `onboardingService.setAtClientPreference = atClientPreference` is now commented out (there's a stray typo comment `// authService. .setAtsign = atsign;` — harmless since it's a comment, but worth cleaning up). There's an open `TODO` in the file: _"Refactor so it uses `BackupKeyCubit`. Can't be used now because it is tightly coupled with the `OnboardingCubit`/Single Atsign Activation flow. This will be refactored when we migrate to `at_client_flutter`."_ — that migration has now happened, so **this refactor is a good next task.**
- `backUpActivatedAtsigns` now reads keys via `KeychainStorage().getAtsign(atsign)` and writes them with `FileAtKeysIo(...).write(atsign, atKeys)` instead of manually building JSON bytes and writing a file — this mirrors the pattern used in `BackupKeyCubit`/`BackUpKeyRepository` (see below).

## 6. Backup key flow

- [lib/features/back_up_key/cubit/backup_key_cubit.dart](lib/features/back_up_key/cubit/backup_key_cubit.dart) and [lib/features/back_up_key/repository/backup_key_repository.dart](lib/features/back_up_key/repository/backup_key_repository.dart): replaced `BackUpKeyService.getEncryptedKeys(atsign)` (from the removed `at_backupkey_flutter` package) with `KeychainStorage().getAtsign(atsign)` → `AtKeys`, written via `FileAtKeysIo`.
- **Explicit TODOs left in both files:** _"Update so it works for single activation as well as multi activation. Currently it only works for single activation..."_ and _"Test that `backUpKeys` works and then remove legacy commented code below."_ The old JSON-encoding code path is left commented out in both files rather than deleted — **this is untested and flagged as such in the migration plan.** Treat backup-key export as unverified until someone runs it end-to-end against a real atsign.

## 7. Switch-atsign / remove-atsign UI

- [lib/widgets/switch_atsign_button.dart](lib/widgets/switch_atsign_button.dart): rewritten to use `KeychainStorage().getAllAtsigns()`, the new `OnboardResult` sealed-class switch, `AtAuthRequest` + `PkamDialog.show(...)` for re-authenticating an existing atsign, and the shared `initializeAfterAuth(...)` helper. The old `AtOnboarding.changePrimaryAtsign(atsign: ...)` call before switching was removed — switching now just calls `preSignout()` then re-runs onboarding for the target atsign directly.
- [lib/widgets/custom_text_button.dart](lib/widgets/custom_text_button.dart): the "remove atsign" action no longer calls `AtOnboarding.reset(...)` / `OnboardingService.getInstance().setAtsign = null`. It now calls `preSignout()` + `KeychainStorage().removeAtsignFromKeychain(atsign)` directly. The whole `BlocBuilder<OnboardingCubit, ...>`-wrapped special case for `removeAtsign` was removed since `onTap` no longer needs `rootDomain` from state.

## 8. Import-only changes (no logic change)

These files just swapped `at_client_mobile` → `at_client_flutter` imports with no behavior change: [lib/features/profile_list/cubit/sync_cubit.dart](lib/features/profile_list/cubit/sync_cubit.dart), [lib/util/uuid.dart](lib/util/uuid.dart), [lib/features/profile/models/profile.dart](lib/features/profile/models/profile.dart), [lib/features/profile_form/widgets/profile_relay_quick_buttons.dart](lib/features/profile_form/widgets/profile_relay_quick_buttons.dart), [lib/features/settings/widgets/settings_relay_at_sign_text_field.dart](lib/features/settings/widgets/settings_relay_at_sign_text_field.dart), [lib/features/policy_form/cubit/policy_form_cubit.dart](lib/features/policy_form/cubit/policy_form_cubit.dart), [lib/features/policy_form/widgets/at_signs_list_widget.dart](lib/features/policy_form/widgets/at_signs_list_widget.dart), [lib/features/policy_form/widgets/user_at_signs_field.dart](lib/features/policy_form/widgets/user_at_signs_field.dart), [lib/features/onboarding/cubit/onboarding_cubit.dart](lib/features/onboarding/cubit/onboarding_cubit.dart), [lib/features/onboarding/util/profile_progress_listener.dart](lib/features/onboarding/util/profile_progress_listener.dart), [lib/features/onboarding/model/multi_activation_file_content.dart](lib/features/onboarding/model/multi_activation_file_content.dart), [lib/features/onboarding/widgets/atsign_selector.dart](lib/features/onboarding/widgets/atsign_selector.dart), and a handful of other repository/model files touched by the `at_client_mobile` → `at_client_flutter` sweep (profile, settings, policy, favorite repositories).

- [lib/util/at_client_methods.dart](lib/util/at_client_methods.dart): also dropped `isLocalStoreRequired = true` from the built `AtClientPreference` (no longer a valid/needed field).

## 9. Test files

Several `.mocks.dart` files were regenerated (Mockito codegen) to match the new `at_client_flutter` types: `profile_repository_test.mocks.dart`, `profile_view_test.mocks.dart`, `profile_list_bloc_test.mocks.dart`, `profile_list_view_test.mocks.dart`, `settings_bloc_test.mocks.dart`, `settings_view_test.mocks.dart`. If you add or change mocked classes, regenerate with:

```
dart run build_runner build --delete-conflicting-outputs
```

`favorite_test.dart`, `profile_view_test.dart`, `settings_test.dart`, `settings_view_test.dart` had minor import/type updates to match.

**Known gap:** per the migration plan, `multi_activation_cubit.dart` production code is migrated but **has no test coverage** — this was already true before this branch and remains true now.

## 10. Verification status — what has and hasn't been run

- Not yet run on this branch as part of this handoff: `flutter pub get`, `flutter analyze`, `flutter test`, or a manual smoke test of the app.
- **Do this first:** `flutter pub get`, then `flutter analyze` (watch for dangling references to `ActivateUtil`/`ActivateAtsignDialog`), then `flutter test`.
- **Manually verify, in this priority order** (these are the flows with the most code churn and the least confidence):
  1. New atsign activation via CRAM (teapot/unavailable atsign) — `RegistrarCramDialog` path
  2. Existing/activated atsign onboarding via atKeys file upload — `AtKeysFileDialog` + `PkamDialog` path
  3. APKAM enrollment dialog ([onboarding_apkam_dialog.dart](lib/features/onboarding/widgets/onboarding_apkam_dialog.dart) was substantially rewritten, ~330 lines)
  4. Switch-atsign and add-atsign flows in [switch_atsign_button.dart](lib/widgets/switch_atsign_button.dart)
  5. Remove-atsign flow in [custom_text_button.dart](lib/widgets/custom_text_button.dart)
  6. Backup-key export (flagged as untested by the code's own TODOs)
  7. Multi-activation (bulk atsign activation from a file) — flagged as untested by the migration plan
  8. Authorization/enrollment request list (approve/deny/revoke) via `EnrollmentRequestList`

## 11. Recommended next steps for the incoming developer

1. Read [at_client_flutter_migration_plan.md](at_client_flutter_migration_plan.md) in full — it has the complete legacy→new API mapping table this branch was built from.
2. Confirm satisfaction with the migration guide with developer and modify accordingly
3. Revaluate the codebase and confirm the information here is accurate and determine the gap between the current codebase state and the migration guide.
4. Run `flutter pub get` / `flutter analyze` / `flutter test` and fix anything that surfaces.
5. Delete [activate_util.dart](lib/features/onboarding/util/activate_util.dart) and [activate_atsign_dialog.dart](lib/features/onboarding/widgets/activate_atsign_dialog.dart) (confirmed dead code — see section 4).
6. Manually walk through the flows listed in section 10, in priority order.
7. Resolve the two explicit backup-key TODOs and the multi-activation `BackupKeyCubit` refactor TODO (sections 5 and 6).
8. Clean up the stray commented-out code/typo left in `multi_activation_cubit.dart` (section 5).
