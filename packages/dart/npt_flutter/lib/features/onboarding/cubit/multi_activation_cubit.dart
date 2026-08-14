// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:at_lookup/at_lookup.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/multi_activation_file_content.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/widgets/activation_dialog_initial.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// state of the file based activation flow.
enum MultiActivationFileUploadState { idle, loading, success, error }

/// keeps track of the state of the file based activation flow including the content of the file and the current upload state.
class MultiActivationState {
  final MultiActivationFileUploadState uploadState;
  final MultiActivationFileContent fileContent;

  /// True while [MultiActivationCubit.activateAll] is working through the
  /// entries. The UI must not offer sign in / retry while this is set.
  final bool isActivating;

  MultiActivationState({
    required this.uploadState,
    required this.fileContent,
    this.isActivating = false,
  });

  MultiActivationState copyWith({
    MultiActivationFileUploadState? uploadState,
    MultiActivationFileContent? fileContent,
    bool? isActivating,
  }) {
    return MultiActivationState(
      uploadState: uploadState ?? this.uploadState,
      fileContent: fileContent ?? this.fileContent,
      isActivating: isActivating ?? this.isActivating,
    );
  }
}

/// A cubit which tracks the state of the file based activation flow.
class MultiActivationCubit extends Cubit<MultiActivationState> {
  MultiActivationCubit()
    : super(
        MultiActivationState(
          uploadState: MultiActivationFileUploadState.idle,
          fileContent: MultiActivationFileContent(entries: [], fileName: ''),
        ),
      );

  /// Bulk activation only ever onboards atsigns we have just confirmed are up
  /// and sitting in teapot, so there is no newly-registered atsign to wait for
  /// provisioning. Without this, `AtAuth` falls back to
  /// `AtNetworkTimeouts.defaultOnboardingTimeout` (5 minutes) per atsign, and a
  /// file full of dud atsigns stalls the dialog for 5 minutes each.
  static const Duration onboardTimeout = Duration(seconds: 90);

  /// Where the .atKeys backups go. Remembered from the first [activateAll] run
  /// so a retry doesn't re-prompt for the folder.
  String? _backupDirectory;

  /// Read the activation file and update the state with the content of the file and the upload state.
  Future<void> processFile(String filePath, String fileName) async {
    try {
      File f = File(filePath);

      var data = loadYaml(await f.readAsString());
      emit(
        state.copyWith(
          fileContent: MultiActivationFileContent.fromYaml(data, fileName),
          uploadState: MultiActivationFileUploadState.success,
        ),
      );

      App.log('uploaded activation file content successfully'.loggable);
    } catch (e) {
      emit(state.copyWith(uploadState: MultiActivationFileUploadState.error));
      App.log('Error processing activation file: $e'.loggable);
    }
    return;
  }

  /// Get the activation file path from the file picker.
  Future<void> getFilePickerPath() async {
    emit(state.copyWith(uploadState: MultiActivationFileUploadState.loading));

    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml'],
    );

    if (result == null) {
      emit(state.copyWith(uploadState: MultiActivationFileUploadState.idle));
      return;
    }

    await processFile(result.files.single.path!, result.files.single.name);
  }

  /// Get the activation file path from the drag and drop.
  Future<void> getDragAndDropPath(DropDoneDetails details) async {
    emit(state.copyWith(uploadState: MultiActivationFileUploadState.loading));

    await processFile(details.files.single.path, details.files.single.name);
  }

  /// Set the new state of the file upload flow.
  void setActivationFileUploadState(MultiActivationFileUploadState newState) {
    emit(state.copyWith(uploadState: newState));
  }

  /// Reset the file upload flow to the initial state (idle with empty file content).
  void reset() {
    _backupDirectory = null;
    emit(
      MultiActivationState(
        uploadState: MultiActivationFileUploadState.idle,
        fileContent: MultiActivationFileContent(entries: [], fileName: ''),
      ),
    );
  }

  /// Get the atsign that is currently being activated.
  Atsign? getActivatingAtsign() {
    try {
      final ActivationKeyPair activationKeyPair = state.fileContent.entries
          .firstWhere(
            (entry) =>
                entry.activationKeyStatus == ActivationKeyStatus.activating,
          );
      return activationKeyPair.atsign;
    } catch (e) {
      return null;
    }
  }

  /// Put every previously failed Atsign back to waiting and run [activateAll]
  /// again. The already activated ones are left alone.
  Future<void> retryFailed() async {
    if (state.isActivating) return;

    final entries = state.fileContent.entries
        .map(
          (entry) => entry.activationKeyStatus == ActivationKeyStatus.failed
              ? entry.copyWith(
                  activationKeyStatus: ActivationKeyStatus.waiting,
                  clearFailureReason: true,
                )
              : entry,
        )
        .toList();

    emit(
      state.copyWith(
        fileContent: state.fileContent.copyWith(entries: entries),
      ),
    );

    await activateAll();
  }

  /// Activate all Atsigns in the activation file.
  Future<void> activateAll() async {
    if (state.isActivating) return;

    //0. Prompt to atKeys file location to save files.
    final context = App.navState.currentContext!;
    final strings = AppLocalizations.of(context)!;

    // Only ask once per activation file - a retry reuses the same folder.
    String? selectedDirectory =
        _backupDirectory ??
        await FilePicker.getDirectoryPath(
          dialogTitle: strings.activationAtsignFileStorageLocation,
        );

    if (selectedDirectory == null) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (context) => const ActivationDialogInitial(),
      );
      // User cancelled the picker
      return;
    }
    _backupDirectory = selectedDirectory;

    // 1. create a mutable copy of the entries to update the status of each entry as we go through the activation process
    // TODO: re-evalaute if a copy is necessary here or if we can just update the entries directly since we are emitting a new state with the updated entries each time we update the status of an atsign
    var currentEntries = List<ActivationKeyPair>.from(
      state.fileContent.entries,
    );

    final onboardingUtil = await NoPortsOnboardingUtil.create(
      App.navState.currentContext!,
    );

    emit(state.copyWith(isActivating: true));

    void publish() {
      emit(
        state.copyWith(
          fileContent: state.fileContent.copyWith(
            entries: List.from(currentEntries),
          ),
        ),
      );
    }

    try {
      for (int i = 0; i < currentEntries.length; i++) {
        var entry = currentEntries[i];

        // A retry only re-runs the entries that are still waiting.
        if (entry.activationKeyStatus != ActivationKeyStatus.waiting) continue;

        //1. Ask the atServer where this atsign stands. AtStatusImpl swallows
        // its own errors, but guard anyway - one bad atsign must not abort the
        // whole file.
        AtSignStatus? status;
        try {
          status = (await onboardingUtil.atServerStatus(entry.atsign)).status();
        } catch (e) {
          App.log('Error checking status of ${entry.atsign}: $e'.loggable);
          status = null;
        }

        if (status == AtSignStatus.activated) {
          currentEntries[i] = entry.copyWith(
            activationKeyStatus: ActivationKeyStatus.alreadyActivated,
          );
          publish();
          App.log('Atsign ${entry.atsign} is already activated.'.loggable);
          continue;
        }

        // Nothing to onboard against: the atsign isn't in the atDirectory, or
        // its atServer is down. Fail it now instead of letting AtAuth poll for
        // provisioning that is never coming.
        if (status != AtSignStatus.teapot) {
          currentEntries[i] = entry.copyWith(
            activationKeyStatus: ActivationKeyStatus.failed,
            failureReason: await _unreachableReason(
              onboardingUtil,
              entry.atsign,
              strings,
            ),
          );
          publish();
          App.log(
            'Skipping ${entry.atsign}: atServer status is $status'.loggable,
          );
          continue;
        }

        //2. Update status to Activating
        currentEntries[i] = entry.copyWith(
          activationKeyStatus: ActivationKeyStatus.activating,
        );
        publish();
        App.log('Activating atsign ${entry.atsign}...'.loggable);

        try {
          // A fresh AuthService() per atsign: AtAuthImpl caches atLookUp/atChops
          // internally, so reusing one instance across atsigns would
          // authenticate the second atsign against the first one's lookup.
          Atsign atsign = entry.atsign;
          String cramSecret = entry.activationKey;

          // The atServer says this atsign is in teapot, so any keys we still
          // hold for it locally are from a previous life of the atsign (it was
          // reset on the registrar). AtAuth.onboard refuses to run at all while
          // they exist, so drop them first.
          await NoPortsOnboardingUtil.discardStaleKeys(atsign);

          var onboardingRequest = AtOnboardingRequest(atsign)
            ..rootDomain = AtRootDomain.parse('root.atsign.org');

          var response = await AuthService().onboard(
            onboardingRequest,
            cramSecret,
            timeout: onboardTimeout,
          );

          // Bulk activation never brings up an AtClient for these atsigns, so
          // each iteration must close its own authenticated lookup - nothing
          // else owns it.
          await (response.atLookUp as AtLookupImpl?)?.close();

          // 6. Update Result
          if (response.isSuccessful) {
            await backUpActivatedAtsigns(selectedDirectory, atsign);
            currentEntries[i] = entry.copyWith(
              activationKeyStatus: ActivationKeyStatus.activated,
            );
            App.log('Successfully activated ${entry.atsign}'.loggable);
          } else {
            // Change to show that it failed to activate.`
            currentEntries[i] = entry.copyWith(
              activationKeyStatus: ActivationKeyStatus.failed,
              failureReason: strings.errorAuthenticatinFailed,
            );
            App.log('Failed to activate ${entry.atsign}'.loggable);
          }
        } catch (e) {
          App.log('Exception activating ${entry.atsign}: $e'.loggable);
          currentEntries[i] = entry.copyWith(
            activationKeyStatus: ActivationKeyStatus.failed,
            failureReason: _failureReason(e, strings),
          );
        }

        // Emit final state for this iteration
        publish();
      }
    } finally {
      emit(state.copyWith(isActivating: false));
    }

    if (currentEntries.every(
      (entry) => entry.activationKeyStatus == ActivationKeyStatus.activated,
    )) {
      App.log('All Atsigns activated successfully!'.loggable);
    } else if (currentEntries.any(
      (entry) =>
          entry.activationKeyStatus == ActivationKeyStatus.alreadyActivated,
    )) {
      App.log(
        'Some Atsigns were already activated. No activation was attempted for those Atsigns.'
            .loggable,
      );
    } else if (currentEntries.any(
      (entry) => entry.activationKeyStatus == ActivationKeyStatus.failed,
    )) {
      App.log(
        'Some Atsigns failed to activate. Please check the status for each Atsign.'
            .loggable,
      );
    }
  }

  /// Says why an atsign the atServer wouldn't talk to is unreachable.
  ///
  /// `AtStatusImpl` swallows the atDirectory exception and reports both "this
  /// atsign has no atDirectory entry" and "the atDirectory is unreachable" as
  /// [AtSignStatus.unavailable], which are very different things for a tester
  /// staring at a failed row. Ask the atDirectory directly - it only happens on
  /// the failure path, and it answers in a couple of hundred milliseconds.
  Future<String> _unreachableReason(
    NoPortsOnboardingUtil onboardingUtil,
    Atsign atsign,
    AppLocalizations strings,
  ) async {
    try {
      await CacheableSecondaryAddressFinder(
        onboardingUtil.rootDomain,
        64,
      ).findSecondary(atsign);
      // The atDirectory knows this atsign, so its atServer is down or still
      // being provisioned.
      return strings.errorAtsignUnavailable;
    } on SecondaryNotFoundException {
      return strings.errorAtsignNotExist;
    } catch (_) {
      return strings.errorAtServerUnavailable;
    }
  }

  /// Turns an onboarding exception into something a tester can act on.
  String _failureReason(Object e, AppLocalizations strings) {
    final message = e.toString();
    if (message.contains('already onboarded')) {
      // discardStaleKeys should have cleared this, so reaching here means the
      // keys live somewhere we didn't clean (e.g. a stale FileAtKeysIo path).
      return strings.errorActivationKeysConflict;
    }
    if (e is AtTimeoutException) return strings.errorAuthenticationTimedOut;
    return message;
  }

  /// Check if any Atsign has a failed activation status.
  bool isAnyFailedStatus() {
    return state.fileContent.entries.any(
      (entry) => entry.activationKeyStatus == ActivationKeyStatus.failed,
    );
  }

  /// Check if any Atsign has an activated or already activated status.
  bool isAnyActivatedStatus() {
    return state.fileContent.entries.any(
      (entry) =>
          entry.activationKeyStatus == ActivationKeyStatus.activated ||
          entry.activationKeyStatus == ActivationKeyStatus.alreadyActivated,
    );
  }

  /// True once every entry has reached a terminal status.
  ///
  /// Sign in must stay disabled until this is true. Signing in mid-run starts
  /// an APKAM enrolment (OTP by email) against an atsign whose onboarding is
  /// still in flight, which ends with the app holding a second set of keys and
  /// prompting to replace the ones bulk activation just wrote.
  bool isActivationComplete() {
    if (state.isActivating) return false;
    return !state.fileContent.entries.any(
      (entry) =>
          entry.activationKeyStatus == ActivationKeyStatus.waiting ||
          entry.activationKeyStatus == ActivationKeyStatus.activating,
    );
  }

  /// The atsign to sign in with once activation finishes: the last one that
  /// actually made it through, so a trailing failure doesn't hand the
  /// onboarding flow an atsign that was never activated.
  Atsign? getSignInAtsign() {
    for (final entry in state.fileContent.entries.reversed) {
      if (entry.activationKeyStatus == ActivationKeyStatus.activated ||
          entry.activationKeyStatus == ActivationKeyStatus.alreadyActivated) {
        return entry.atsign;
      }
    }
    return null;
  }

  // Back Up the atKeys for the activated Atsign.
  Future<void> backUpActivatedAtsigns(
    String fileLocation,
    Atsign atsign,
  ) async {
    // AuthService().onboard defaults to writing through KeychainAtKeysIo, so
    // the freshly-activated keys are already in the keychain at this point.
    final atKeys = await KeychainStorage().getAtsign(atsign);
    if (atKeys == null) return;

    final filePath = path.join(fileLocation, '${atsign}_key.atKeys');
    final file = File(filePath);
    if (await file.exists()) await file.delete();
    await FileAtKeysIo(filePath: (_) => filePath).write(atsign, atKeys);
  }

  /// Check if any Atsign is still waiting for activation.
  bool isAnyWaitingStatus() {
    return state.fileContent.entries.any(
      (entry) => entry.activationKeyStatus == ActivationKeyStatus.waiting,
    );
  }

  // Get the overall activation state to show in the UI based on the status of each individual atsign activation.
  String overallActicationState() {
    if (isAnyWaitingStatus()) {
      return 'Activating';
    } else if (isAnyActivatedStatus()) {
      return 'Activation Completed';
    } else {
      return "Activation Failed";
    }
  }
}
