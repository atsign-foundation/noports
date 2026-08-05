# Migrating off at_onboarding_flutter and at_client_mobile — direction and decisions

Status: not started. Planned as two PRs against `packages/dart/npt_flutter`. Migration incomplete.

## Direction

npt_flutter depends on two git-pinned forks that cannot be released or audited:

```yaml
at_onboarding_flutter:   # git at_widgets, ref at_onboarding_flutter_layers
at_client_mobile:        # git at_client_sdk, ref 4e7701af851be6a7c45ef2cecbf4048c80814261
```

Being frozen git refs, they are invisible to the `osv-scanner` job in `.github/workflows/npt_flutter_tests.yaml` and the `sbomify` job in `npt_flutter_release.yaml`. They are also the reason 13 of the 14 `dependency_overrides` entries exist: `at_onboarding_flutter` declares `at_auth ^2.0.7`, `archive ^3.4.10`, `file_picker ^8.1.1`, and every one of those has to be forced forward.

The onboarding, keychain, and enrollment logic these packages carried now exists as reusable primitives in `at_client_flutter`, published on pub.dev. npt_flutter moves to `at_client_flutter: ^1.1.4` and owns the app-specific glue itself — the result type, the keychain facade, the `.atKeys` export, and the authorization hub.

Two PRs, in order:

1. Replace the deprecated packages. Remove only the overrides that block resolution.
2. Slim the pubspec — drop the remaining redundant overrides and unused dependencies.

`at_backupkey_flutter` (→ `at_client_mobile ^3.2.19`) and `at_contacts_flutter` (→ `at_client_mobile ^3.3.0`) both declare direct dependencies on at_client_mobile, so both go in PR 1. Leaving either keeps at_client_mobile in `pubspec.lock`, which makes PR 1 a no-op in substance.

## Decisions

**`at_client_flutter` comes from pub.dev at `^1.1.4` — no git ref, no path override.** Replacing two git pins with a third defeats the purpose. The local `at_client_sdk/trunk` checkout carries an unreleased 1.1.5; wait for a release rather than pinning a path.

**`environment: sdk` rises to `^3.11.0`.** `at_client_flutter-1.1.4/pubspec.yaml` declares `sdk: ^3.11.0` while npt_flutter declares `^3.10.0`. Resolution succeeds on a machine whose Dart is new enough, so the mismatch is latent rather than fatal — which is exactly why it should be stated honestly instead of left to fail the first time CI pins 3.10.

**The app `version:` stays `1.9.3+30` and `msix_config` is untouched.** Versioning is a release-time decision, not a migration artifact. Note that `msix_config.msix_version` is independently pinned at `1.9.3.0` and would need syncing whenever the version does move.

**`at_onboarding_cli`, `at_auth`, and `at_chops` overrides form one atomic group that must go in PR 1.** The `at_onboarding_cli: 1.14.2` override is exact-pinned, and that version requires `at_auth ^2.3.0` / `at_chops ^2.2.0`. Removing the `at_auth` override while keeping the pin leaves `^3.2.0 ∩ ^2.3.0` — empty, and `pub get` fails. Unpinning lets pub take at_onboarding_cli 1.16.0, which declares `at_auth ^3.2.0` / `at_chops ^3.0.0` and therefore agrees with at_client_flutter. Both `noports_core` call sites — `../noports_core/lib/src/commands/issue_keys/issue_keys.dart` and `../noports_core/lib/src/commands/activate/activate.dart` — use only symbols 1.16.0 still exports.

**The `at_utils`, `at_auth`, and `at_chops` overrides were never conflicting with at_client_flutter.** `^3.0.15` includes 3.4.0. They are removable because their cause — at_onboarding_flutter and the at_onboarding_cli pin — is being deleted, not because at_client_flutter forces it.

**`file: 7.0.1` and `meta: ^1.17.0` stay in both PRs. Both are tripwires.** `device_info_plus 11.3.3` needs `file ^7.0.1` while `../noports_core/pubspec.yaml` declares `^6.0.0` — disjoint, and `noports_core/lib/src/common/io_types.dart` re-exports `package:file`, so the constraint is real. The Flutter SDK pins `meta: 1.17.0` exactly while `analyzer >=10.0.2` needs `^1.18.0`; removing that override makes pub silently downgrade analyzer 10.2.0 → 10.0.1, dragging the whole codegen toolchain backwards with no error. The clean fix for `file` is bumping `noports_core` to `^7.0.1`, which is a separate deliberate change.

**`pointycastle: ^4.0.0` stays permanently.** at_chops caps pointycastle at `^3.9.1`; `dartssh2` (via `noports_core`) needs `^4.0.0`. Disjoint, and unresolvable without an upstream at_chops release. `pqcrypto`, arriving as a new transitive, also wants `^4.0.0`.

**Every successful auth path calls `AtClientMethods.activateFromAuthResponse` before anything touches `AtClientManager.atClient`.** This is the load-bearing semantic difference. `at_onboarding_flutter`'s `AtOnboarding.onboard()` implicitly called `AtClientManager.setCurrentAtSign(...)` after authenticating; at_client_flutter's primitives only perform CRAM/PKAM/APKAM and hand back keys. PKAM returns `AtAuthResponse`, APKAM returns `AtEnrollmentResponse`, and the two are unrelated types — hence one shared helper taking the common `AuthResponse` supertype rather than a method per flow. `AtClientManager.fromAuthSession` does not exist in any published at_client; the at_client_sdk trunk walkthrough is ahead of pub. Use `setCurrentAtSign`, whose `{AtChops?, AtLookUp?, String? enrollmentId}` parameters are present as far back as at_client 3.11.0.

**The 29-file `at_client_mobile` import swap targets `package:at_client/at_client.dart`, not `at_client_flutter`.** Four files already do exactly this for identical work — `lib/features/policy/models/policy.dart`, `lib/features/policy_form/widgets/daemon_at_signs_field.dart`, `lib/features/policy/cubit/status_light/policy_status_light_cubit.dart`, `lib/features/profile_form/widgets/profile_device_at_sign_text_field.dart` — so `at_client` is the existing house convention and choosing at_client_flutter would create two conventions for one job. Every symbol in play (`Atsign`, `String.toAtsign()`, `AtClient`, `AtClientManager`, `AtClientPreference`, `AtKey`, `AtValue`, `NotificationParams`, `AtNotification`, `SyncProgressListener`, `SyncProgress`, `SyncStatus`, `EnrollmentStatus`) originates in at_client or at_commons, which both packages re-export identically. It also keeps at_client_flutter's 20+ widget libraries — including its own `src/widgets/file_picker.dart`, which would sit next to `package:file_picker` — out of 29 unrelated files. Reserve `at_client_flutter` imports for the files that use its auth, keychain, or widget API.

**npt_flutter keeps its explicit `AtStatus` pre-check before onboarding.** `AtAuthImpl.onboard` → `validateAtServer` retries every failure, including `already onboarded`, until a 5-minute deadline and then throws `AtTimeoutException`. Without the pre-check, calling `onboard()` on an already-activated atsign is a five-minute hang rather than a fast error.

**Keychain login passes no `backupKeys:`; `.atKeys`-file and APKAM login do.** `KeychainStorage.appendAtKeysToKeychain` appends without dedup, so passing a keychain backup target on a keychain login adds a duplicate entry on every single sign-in. `getAllAtsigns()` dedupes through a `Set`, so the growth is invisible until Windows credential segmenting starts chewing through it.

**`changePrimaryAtsign` is deleted, not replaced.** `AtKeysData.defaultAtsign` is readable but nothing in `KeychainStorage` sets it — `_write` is private. npt_flutter only ever wrote it to satisfy at_onboarding_flutter's start screen, which authenticated whatever the keychain called primary; npt_flutter never read it. Every new auth call passes the atsign explicitly in `AtAuthRequest`, and `OnboardingCubit.state.atsign` plus `atsign_information.json` are already the source of truth. `strings.errorSwitchAtsignFailed` becomes unused.

**Approve, deny, and revoke bypass `FlutterEnrollmentService` and call `at_auth` directly.** `AtEnrollment.create().approve(EnrollmentRequestDecision.approved(...), atLookUp)` on a short-lived `AtLookupImpl` that npt_flutter owns and closes in a `finally`. Three defects in at_client_flutter 1.1.4 force this, all in `enrollment_service.dart:95-112`: `validateEnrollment(request.atSign)` reads *this device's own* submitted-enrollment record, which a CRAM- or `.atKeys`-onboarded approver never has, so approve always throws `Invalid enrollment`; the method writes the approved app's keys into the approver's keychain and wipes the approver's own record; and `await atLookUp.close()` tears down the live AtClient's connection. The same `close()` appears in `deny` and `revoke`. `EnrollmentRequestList` inherits all three and is English-only, so it cannot be dropped in either.

**npt_flutter avoids `AtKeysFileDialog`, `RegistrarCramDialog`, and `ApkamActivationDialog` entirely.** All three are hard-coded English and npt_flutter ships seven locales. `AtKeysFileDialog` additionally resolves the atsign from the *filename*, which silently misidentifies a renamed `.atKeys` file — npt_flutter reads it from file content (`keys.atsign`, else the `@`-prefixed `metadata` entry) and keeps the filename only as a last resort. `ApkamActivationDialog` hard-codes `waitForApproval: true` inside `enroll`, which makes npt_flutter's `pendingApproval` screen unrenderable. `PkamDialog` and `CramDialog` are usable because they accept localizable `title:` and `description:`.

**`AtEnrollmentRequest(atSign:, rootDomain:)` are used despite being `@Deprecated`.** The replacement is `session:`, an `AtAuthSession` available only *after* authenticating — and this is the login. Upstream's own `ApkamActivationDialog` uses the deprecated parameters for the same reason.

**`multi_activation_cubit.dart` constructs a fresh `AuthService()` per atsign.** `AtAuthImpl` caches `atLookUp`, `atChops`, and `_atAuthKeys` with `??=`, so one reused instance authenticates the second atsign against the first one's lookup. Per-atsign instances share no state, which resolves the singleton problem flagged by the existing TODOs rather than working around it. Bulk activation never brings up an AtClient, so each iteration must also `await (response.atLookUp as AtLookupImpl?)?.close()` — nothing else owns those authenticated sockets.

**`exportAtKeysBytes` sets `keys.metadata[atsign]` before writing.** `AtKeys._toLegacyJson` emits metadata entries flat, so this restores the `"@alice": "<selfEncryptionKey>"` entry that older atsign apps use to locate the atsign inside a keys file. Without it, `.atKeys` files exported by NoPorts Desktop are not loadable by older atsign apps. The helper also deletes any existing target file first, because `FileAtKeysIo.write` throws `AtKeysFileOverwriteException` and both call sites — re-backup and retry-activation — overwrite by design.

**`NoPortsKeychain.getAtsignList()` wraps `getAllAtsigns()` in a try/catch.** `keychain_storage.dart:91` reads `} else if (atKeysData.keys[i].metadata['name']) {` — a `dynamic` used as an `if` condition. Dart implicitly downcasts to `bool`, so it compiles but throws `TypeError` at runtime for any entry lacking `metadata['atsign']`.

**`NoPortsEnrollmentService` wraps a nullable `FlutterEnrollmentService?` rather than typing against it directly.** `FlutterEnrollmentService` wires `onListen` in its constructor and `dispose()` nulls the controller permanently, so an instance is dead after one sign-out. npt_flutter's `RepositoryProvider` singleton plus the `post_onboard`/`pre_offboard` lifecycle cannot map onto that 1:1 — the old `AuthorisationService.init()`/`dispose()` were re-callable.

**`file_picker` moves to `^11.0.2`, which is source-breaking.** `at_client_flutter-1.1.4` requires `file_picker: ^11.0.02` while npt_flutter pins `^10.3.3` in both `dependencies` and `dependency_overrides` — disjoint. In v11 `FilePicker` is an `abstract final class` with static methods and `FilePicker.platform` no longer exists. The override cannot stay at `^10` even in principle, because at_client_flutter's barrel re-exports its own `src/widgets/file_picker.dart`, which calls `FilePicker.pickFiles(...)`. Six call sites need `FilePicker.platform.X(` → `FilePicker.X(`: `lib/util/export.dart` (twice), `lib/features/back_up_key/repository/backup_key_repository.dart`, `lib/features/logging/widgets/export_logs_button.dart`, and `lib/features/onboarding/cubit/multi_activation_cubit.dart` (twice).

**`package_info_plus` moves to `^9.0.1`.** `at_client_flutter-1.1.4` requires it and npt_flutter's `^8.3.0` is disjoint. Version 9 is breaking for Android only — it needs AGP ≥8.12.1 and Gradle ≥8.13, while `android/gradle/wrapper/gradle-wrapper.properties` pins 7.6.3. Neither CI workflow builds Android (release builds only `flutter build windows`), so this is a local `flutter build apk` break, not a CI one. Android is deliberately out of scope.

**`biometric_storage` needs no new platform configuration.** It stays at 5.0.1, the version already in the lock and exactly what at_client_flutter 1.1.4 requires. Both packages call `getStorage(name, options: StorageFileInitOptions(authenticationRequired: false))`, so no `keychain-access-groups` entitlement, no `USE_BIOMETRIC` permission, and no `NSFaceIDUsageDescription` become newly required. Existing `macos/Runner/*.entitlements` suffice. On Windows it registers from Dart via `Win32BiometricStoragePlugin.registerWith()`, so it correctly stays absent from `windows/flutter/generated_plugins.cmake`.

**All eight `.mocks.dart` files regenerate, unconditionally.** Two hard-code the dying import — `test/features/profile_list/view/profile_list_view_test.mocks.dart` and `test/features/settings/bloc/settings_bloc_test.mocks.dart` — so leaving them stale is a hard compile failure once at_client_mobile leaves the lock. The rest move because at_chops 3.0.0 → 3.3.0 and at_lookup 3.5.0 → 3.6.0 change types appearing in the generated `AtClient`/`AtClientManager` signatures. They are independently stale already: headers say Mockito 5.4.6 while the lock resolves 5.6.4.

**`at_lookup` and `at_chops` become direct dependencies.** The migration code imports both directly, and `test/features/profile/repository/profile_repository_test.mocks.dart` already does — currently a `depend_on_referenced_packages` lint that CI swallows via `flutter analyze --no-fatal-warnings --no-fatal-infos`.

**`at_contact`, `at_contacts_flutter`, and their three consumer files go together.** `initializeContactsService()` fetches the atsign's contact list into an in-memory cache that nothing in the app ever reads, so its only live effect is a wasted network round-trip on login. `lib/features/settings/repository/contact_repository.dart`, `lib/features/settings/widgets/contact_list_tile.dart`, and `lib/features/settings/widgets/settings_switch_atsign_action.dart` have zero references anywhere in `lib/` or `test/` — the last already has its at_contact imports commented out. NoPorts Desktop has no contacts feature; removing all of it costs no user-visible functionality.

## PR 1 — replace the deprecated packages

`pubspec.yaml`: `environment: sdk: ^3.11.0`. From `dependencies` remove `at_backupkey_flutter`, `at_client_mobile`, `at_contact`, `at_contacts_flutter`, the `at_onboarding_flutter` git block, and the commented `# at_client_flutter: ^0.1.2`; then set `at_auth: ^3.2.0`, `at_chops: ^3.0.0`, `at_client_flutter: ^1.1.4`, `at_lookup: ^3.6.0`, `at_utils: ^3.4.0`, `file_picker: ^11.0.2`, `package_info_plus: ^9.0.1`. From `dependency_overrides` remove `at_auth`, `at_chops`, `at_client_mobile`, `at_onboarding_cli`, `at_onboarding_flutter`, `at_utils`, `file_picker`, leaving `archive`, `chalkdart`, `device_info_plus`, `file`, `flutter_lints`, `intl`, `meta`, `pointycastle`.

New files:

| File | Holds |
| --- | --- |
| `lib/features/onboarding/model/onboarding_result.dart` | `NoPortsOnboardingResult` and `enum NoPortsOnboardingResultStatus { success, error, cancel }`. Mirrors `AtOnboardingResult`'s `status` / `atsign` / `message` minus the never-read `errorCode`, so the ~30 call-site diffs stay pure renames. Carries no `AuthResponse` — each auth path activates the AtClient itself, so ownership is never ambiguous and no deprecated type crosses a module boundary. |
| `lib/features/onboarding/util/noports_keychain.dart` | Facade over `KeychainStorage`: `getAtsignList`, `contains`, `getKeys`, `getDefaultAtsign`, `remove`, `removeAll`. |
| `lib/features/back_up_key/util/atkeys_export.dart` | `exportAtKeysFile({required Atsign atsign, required String filePath})`, replacing `BackUpKeyService.getEncryptedKeys`. |
| `lib/features/authorisation/service/noports_enrollment_service.dart` | The nullable `FlutterEnrollmentService?` wrapper; reads and streams delegate, decisions go to `at_auth`. |
| `lib/features/authorisation/widgets/noports_authorisation_hub.dart` | Requests pane: `ListView` of at_client_flutter's `EnrollmentRequestCard` with npt_flutter's own callbacks. Keeps `ValueKey('authorization_hub_$atsign')`. |
| `lib/features/onboarding/widgets/reset_atsign_dialog.dart` | Replaces `AtOnboarding.reset`: `CheckboxListTile` per atsign plus select-all over `NoPortsKeychain.getAtsignList()`. |

`lib/util/at_client_methods.dart` gains `activateFromAuthResponse(AuthResponse, String rootDomain)` — the single place the `@Deprecated('remove in v4 in favour of AtAuthSession')` annotations on `AuthResponse.atChops` and `.atLookUp` are tolerated.

`lib/features/onboarding/util/onboarding_util.dart` is the heaviest rewrite. It drops the `AtOnboardingConfig` field, `AtKeysFileUploadService`, `uploadAtKeysFile`, `_handleFileUploadStatusStream`, the exhaustive sealed `FileUploadStatus` switch, the `export ... show FileUploadStatus` (nothing imports it), `AtOnboardingConstants.setApiKey`/`rootDomain`, `AtOnboardingLocalizations.load`, `initializeContactsService`, the `onProgress` plumbing, and the `changePrimaryAtsign` block. State reduces to `String rootDomain` plus `String? apiKey`, and the file gains three auth entry points — keychain login, `.atKeys`-file login, and APKAM delegation — each ending in `activateFromAuthResponse`. The seven `FileUploadStatus` error variants collapse into `FileAtKeysIo.read()` throwing plus two pre-checks; the four progress variants only ever logged a string.

`lib/features/onboarding/util/activate_util.dart` keeps npt_flutter's registrar HTTP layer. at_auth's `RegistrarService` hard-codes `apiBase = '/api/app/v4'` while NoPorts is on v3, and `RegistrarCramDialog.show` takes a concrete `RegistrarService` rather than the `Registrar` interface, so a NoPorts implementation could only be injected by subclassing. The private `at_onboarding_flutter/src/utils/at_onboarding_response_status.dart` import and its re-export both go; the three bare-enum equality checks become real `on AtTimeoutException` / `on AtAuthenticationException` clauses. `AuthService().onboard(...)` takes **no** `timeout:` — a short timeout truncates the provisioning wait that `validateAtServer` performs internally on a five-minute budget, which also makes the hard-coded `Future.delayed(10s)` and the `while (status != activated)` poll redundant. Fix the pre-existing bug on the way through: `innerClient`, built with a `badCertificateCallback`, is discarded because `_http = IOClient()` takes no argument — it should be `IOClient(innerClient)`.

`lib/features/onboarding/widgets/onboarding_apkam_dialog.dart` keeps its own `enum OnboardingStatus` and its `PinCodeTextField` UI verbatim. `AtAuthServiceImpl` maps to `KeychainStorage().readEnrollmentData(atsign)` for the resume path, `FlutterEnrollmentService().enroll(...)` for submission, and `AtEnrollment.create().waitForApproval(response, maxRetries:, retryInterval:)` called directly — `FlutterEnrollmentService.awaitApproval` forwards no options. On approval, `PkamDialog.show(..., backupKeys: [KeychainAtKeysIo()])` then `activateFromAuthResponse`. Both the approve and deny paths must explicitly `deleteEnrollmentData(atsign)`; nothing on the requester side does, so a denied device otherwise resumes waiting on a dead enrollment every launch.

`lib/features/onboarding/cubit/multi_activation_cubit.dart` drops `OnboardingService.getInstance()`, `setAtsign`, `setAtClientPreference`, and the inline `AtClientPreference` block, since `AuthService.onboard` takes no preference. It also threads `rootDomain` from `OnboardingCubit` instead of the hard-coded `'root.atsign.org'`.

`lib/widgets/switch_atsign_button.dart` swaps its two `KeychainUtil.getAtsignList()` calls for `NoPortsKeychain.getAtsignList()` and deletes three things: the `AtOnboardingConfig` that is assigned and never read, `initializeContactsService`, and `AtOnboarding.changePrimaryAtsign`. `lib/widgets/custom_text_button.dart` collapses to `await ResetAtsignDialog.show(context)` — its `RootEnvironment.Testing` argument was inert, because `AtOnboarding.reset` never touched `AtOnboardingConstants`; only `onboard` did.

`lib/app.dart` drops `AtClientMobileLocalizations.delegate` (at_client_flutter ships no `l10n/`) and swaps both the `AuthorisationService` `RepositoryProvider` and the `PendingRequestsCountCubit` provider to `NoPortsEnrollmentService`. `pending_requests_count_cubit.dart` moves its subscribe out of the constructor into a `start()` called from `post_onboard`, guarded on initialisation — it dereferences `AtClientManager.getInstance().atClient`, which throws `StateError('No atClient yet')` pre-onboarding. `post_onboard.dart` and `pre_offboard.dart` lose their now-dead `hide OnboardingStatus` clauses; neither at_client nor at_client_flutter exports that name. `onboarding_cubit.dart` keeps its own shadowing enum and changes only its import line.

Localization: `AtOnboardingLocalizations` disappears, so the five strings `activate_util.dart` borrows from it (`error_server_unavailable`, `error_atSign_activated`, `msg_atSign_unreachable`, `error_authenticated_failed`, `msg_response_time_out`) need npt_flutter equivalents in `lib/localization/*.arb`. Lift the non-English translations from `at_onboarding_flutter/lib/l10n/intl_{es,pt,pt_BR,zh,zh_Hans_CH,zh_Hant_HK}.arb` **before** removing the dependency — the locale sets match 1:1 minus `fr`.

Generated and native artifacts, all tracked and all requiring regeneration: `pubspec.lock` (also fed to osv-scanner and sbomify), the `linux/flutter/`, `macos/Flutter/`, and `windows/flutter/` plugin registrants and CMake lists, and `macos/Podfile.lock` plus `ios/Podfile.lock`. Expect linux to drop `at_file_saver`; windows to drop `at_file_saver`, `permission_handler_windows`, `share_plus`; macos to drop `at_file_saver`, `share_plus`, `shared_preferences_foundation`, `webview_flutter_wkwebview`. `flutter pub get` does not touch the Podfile.locks — a `flutter build macos --debug` is required.

Commit order, each standing alone: delete the dead contacts surface; add the ARB strings; then the pubspec plus lock plus the six `FilePicker.platform` fixes plus the 34 import swaps squashed together (the pubspec change alone does not analyze); then result type and activation helper; keychain facade; `.atKeys` export; CRAM; bulk activation; APKAM; `onboarding_util.dart`; reset; the `switch_atsign_button.dart` remainder; authorization; the shared "select atsign → onboard" path that `get_started_dialog.dart` and `activation_dialog_final.dart` duplicate; regenerated mocks and native artifacts.

## PR 2 — slim the pubspec

`pubspec.yaml` only; no `lib/` changes.

Remove four overrides that become redundant once at_onboarding_flutter and at_backupkey_flutter are gone: `archive` (existed for `^3.4.10`), `device_info_plus` (for `^10.1.1`), `intl` (`flutter_localizations` already pins `0.20.2` exactly), and `chalkdart` (every consumer allows `>=2.0.9 <4.0.0`). Move `flutter_lints: ^4.0.0` from overrides to `dev_dependencies` — it is misfiled but load-bearing, since `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`. Move `json_serializable: ^6.8.0` from `dependencies` to `dev_dependencies`. Drop `adaptive_theme`, `toml`, and `cupertino_icons`, all of which grep to zero hits across `lib/`, `test/`, and `integration_test/`. Pin `intl: ^0.20.2` instead of `any`. The final overrides block is `file`, `meta`, `pointycastle`.

## Not done yet

- **Keychain migration is not implemented, and every existing user is signed out on upgrade.** at_client_mobile writes to `@atsigns:<packageName>` (colon, `keychain_manager.dart:681-682`); at_client_flutter reads `@atsigns_<packageName>` (underscore, `keychain_store.dart:17-23`). Two different `biometric_storage` entries. at_client_flutter has no fallback and no migration code — grepping its `lib/` for `atsigns`, `:shared`, `migrat`, and `legacy` turns up only the store-name constant. The JSON field names differ too (`pkamPublicKey` vs `aesPkamPublicKey`; `hiveSecret` and `secret` have no counterpart), so a store-name fix alone would be insufficient. Key material is **not** destroyed — the old entry stays orphaned in the OS keychain — but every atsign must be re-activated from its `.atKeys` file. This is accepted deliberately, and needs a release note. A partial bridge exists and is misleading: `KeychainStorage.getAtsign`/`getAllAtsigns` already fall back to a legacy `metadata['name']` key, and `AtKeys._fromLegacyJson` sweeps unrecognized keys into `metadata` — so an old blob *would* be recognized if it ever reached that code. It never does.
- **Prompting a `.atKeys` export before the upgrade is unbuilt and matters more than it looks.** `BackupKeyCubit` defaults to `true`, i.e. assumes keys are already backed up. A single-device user who never exported and re-onboards into APKAM needs approval from another authorized device — unrecoverable.
- **The authorization UI ships with the requests pane only.** The OTP, set-PIN, approved-enrollments, and history panes need rebuilding on at_client_flutter's leaf widgets (`AuthorisationListTile`, `AuthorisationSectionHeader`, `ManageDeviceCard`, `TipCard`, `NamespaceChip`, `AuthorisationFeedbackOverlay`) plus `list([EnrollmentStatus.approved])` and `list([])`. Set-PIN additionally has to enforce exactly 6 characters — `SppData` asserts it, narrowing from the old 6-16 range — and SPP becomes local-only rather than atServer-stored, so an SPP set on another device is invisible.
- **APKAM approval waiting regresses from roughly 48 hours to roughly 48 minutes.** `AtAuthServiceImpl._initEnrollmentAuthScheduler` retried on a `Timer` across app restarts; `waitForApproval` is a foreground `await` with no cancellation. Resuming from `readEnrollmentData` on cold start mitigates it, but the dialog must be open. Note that the abstract declares `maxRetries: 48, retryInterval: 1 min` while the impl declares `15, 2s` — the static type wins, so 48 minutes.
- **CRAM onboarding now blocks up to five minutes** inside `validateAtServer`'s provisioning poll, against the old ≈40 s. Subscribing to `AuthService.progressStream` and rendering `event.msg` is required, not cosmetic — a multi-minute indeterminate spinner reads as a hang.
- **`pqcrypto` and `ffi` arrive as new transitives** via at_chops ≥3.1.0 (3.0.0 is the last without). Pure Dart, no native build step, but a real supply-chain delta the SBOM job will flag.
- **`flutter build apk` breaks** on `package_info_plus` 9 against Gradle 7.6.3. Android is not a shipped target and CI does not build it.
- **`device_info_plus` survives only for `onboarding_apkam_dialog.dart`.** If a later change removes that usage, `device_info_plus` goes too — and with it the `file ^7.0.1` pressure, letting the `file: 7.0.1` override go.

### Upstream follow-ups (at_client_sdk)

None block this migration; all were found while planning it.

- `KeychainStorage` should read the legacy `@atsigns:<packageName>` store and translate it. Every at_client_mobile app hits this.
- `keychain_storage.dart:91` uses a `dynamic` as an `if` condition; it throws `TypeError` on legacy-shaped entries.
- `KeychainStorage._read` writes `EmptyKeychainData()` over the store before rethrowing on any read failure — destructive.
- `appendAtKeysToKeychain` appends without dedup; it needs replace-by-atsign, or a `KeychainAtKeysIo.flush`.
- There is no `KeychainStorage.setDefaultAtsign(String)`; `defaultAtsign` is read-only from outside the package.
- `FlutterEnrollmentService.approve`/`deny`/`revoke`: the `validateEnrollment` precondition, the approver-keychain write, and the `atLookUp.close()`.
- `FlutterEnrollmentService.enroll` writes `microsecondsSinceEpoch` while every reader uses `fromMillisecondsSinceEpoch`, so timestamps land ~1000× in the future and **enrollments never expire**.
- `awaitApproval` should forward `maxRetries` and `retryInterval`, and take a cancellation token.
- `FileAtKeysIo.write` should emit the legacy `"@alice": "<selfEncryptionKey>"` metadata entry for back-compat with older atsign apps.
- at_client_flutter is published with `resolution: workspace` still in its pubspec.

## Verification

With `NPT=packages/dart/npt_flutter` from the repo root:

- `dart run melos bootstrap` from the repo root. The workspace `pubspec.yaml` has no `workspace:` key, so each package resolves independently and npt_flutter's overrides do not leak into `noports_core` or `sshnoports`. While iterating, `flutter pub get` in `$NPT` is the narrower CI equivalent — `get`, not `upgrade`, to keep lock movement minimal.
- **The pass/fail gate for PR 1:** `grep -nE 'at_client_mobile|at_onboarding_flutter|at_backupkey_flutter|at_contacts_flutter|at_contact:' pubspec.lock` must return nothing.
- `grep -nE -A6 '^  (at_client_flutter|at_chops|at_lookup|at_auth|at_commons|biometric_storage|pqcrypto|package_info_plus|file_picker|pointycastle):$' pubspec.lock` — assert at_client_flutter 1.1.4, biometric_storage 5.0.1 unchanged, pointycastle 4.0.0, and note `pqcrypto`/`ffi` appearing.
- `dart run build_runner build --delete-conflicting-outputs`. Needs `.env` to exist; it is gitignored, and CI does `touch .env`.
- `flutter analyze --no-fatal-warnings --no-fatal-infos` matches CI. Run `flutter analyze` strict once as well, to catch the `depend_on_referenced_packages` lints the new direct dependencies should have cleared and any surviving dead `hide OnboardingStatus`.
- `flutter test --exclude-tags=integration`.
- `flutter build macos --debug` to regenerate the Podfile.locks, then `git status --short -- pubspec.lock linux macos windows ios test lib` to confirm every moved artifact is staged.
- `flutter run -d macos`, twice. First on a machine with an existing enrolled atsign: the list is empty and the app asks for onboarding — this is the accepted regression, not a bug. Confirm the old entry survives with `security find-generic-password -l '@atsigns:com.atsign.noports_desktop'`, proving nothing was destroyed. Then from clean: delete both entries, onboard a throwaway atsign end-to-end via CRAM and separately via `.atKeys` file, restart, and confirm the atsign persists. Verify `@atsigns_com.atsign.noports_desktop` now exists. Finally exercise the requests pane — approve an enrollment from a second device and confirm the AtClient connection survives it, which is the `atLookUp.close()` defect.

For PR 2, the same sequence minus the native-artifact step, plus `grep -nE -A6 '^  (analyzer|meta|file|chalkdart|intl|archive|device_info_plus):$' pubspec.lock`: `analyzer` must not drop below 10.2.0 and `meta` must stay 1.18.x. If either moved, the `meta` override was removed after all.

## Reference

- `lib/features/onboarding/util/onboarding_util.dart` — the heaviest consumer of both deprecated packages, and the file the three new auth entry points land in
- `lib/features/onboarding/util/activate_util.dart` — the NoPorts registrar client (`/api/app/v3`), which stays npt_flutter-owned
- `lib/util/at_client_methods.dart` — the only `AtClientPreference` factory, and the home of `activateFromAuthResponse`
- `lib/features/onboarding/cubit/multi_activation_cubit.dart` — bulk activation; carries the TODOs this migration resolves
- `pubspec.yaml` — the 14-entry `dependency_overrides` block this migration exists to shrink
- `~/.pub-cache/hosted/pub.dev/at_client_flutter-1.1.4/lib/src/keychain/keychain_store.dart` — the store-name change behind the forced sign-out
- `~/.pub-cache/hosted/pub.dev/at_client_flutter-1.1.4/lib/src/services/enrollment_service.dart` — the three approve/deny/revoke defects
- `~/.pub-cache/hosted/pub.dev/at_client_flutter-1.1.4/README.md` — the flow-to-API capability table
