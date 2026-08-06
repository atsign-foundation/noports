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

  MultiActivationState({required this.uploadState, required this.fileContent});

  MultiActivationState copyWith({
    MultiActivationFileUploadState? uploadState,
    MultiActivationFileContent? fileContent,
  }) {
    return MultiActivationState(
      uploadState: uploadState ?? this.uploadState,
      fileContent: fileContent ?? this.fileContent,
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

  /// Activate all Atsigns in the activation file.
  Future<void> activateAll() async {
    //0. Prompt to atKeys file location to save files.
    final context = App.navState.currentContext!;
    String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: AppLocalizations.of(
        context,
      )!.activationAtsignFileStorageLocation,
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

    // 1. create a mutable copy of the entries to update the status of each entry as we go through the activation process
    // TODO: re-evalaute if a copy is necessary here or if we can just update the entries directly since we are emitting a new state with the updated entries each time we update the status of an atsign
    var currentEntries = List<ActivationKeyPair>.from(
      state.fileContent.entries,
    );

    final onboardingUtil = await NoPortsOnboardingUtil.create(
      App.navState.currentContext!,
    );

    for (int i = 0; i < currentEntries.length; i++) {
      var entry = currentEntries[i];

      //1. check if atsign is already activated, if so skip to the next one
      final status = await onboardingUtil.atServerStatus(entry.atsign);
      if (status.status() == AtSignStatus.activated) {
        currentEntries[i] = entry.copyWith(
          activationKeyStatus: ActivationKeyStatus.alreadyActivated,
        );
        emit(
          state.copyWith(
            fileContent: state.fileContent.copyWith(entries: currentEntries),
          ),
        );
        App.log('Atsign ${entry.atsign} is already activated.'.loggable);
      }

      if (currentEntries[i].activationKeyStatus ==
          ActivationKeyStatus.alreadyActivated) {
        continue;
      }

      //2. Update status to Activating
      currentEntries[i] = entry.copyWith(
        activationKeyStatus: ActivationKeyStatus.activating,
      );
      emit(
        state.copyWith(
          fileContent: state.fileContent.copyWith(entries: currentEntries),
        ),
      );
      App.log('Activating atsign ${entry.atsign}...'.loggable);

      try {
        // A fresh AuthService() per atsign: AtAuthImpl caches atLookUp/atChops
        // internally, so reusing one instance across atsigns would
        // authenticate the second atsign against the first one's lookup.
        Atsign atsign = entry.atsign;
        String cramSecret = entry.activationKey;

        var onboardingRequest = AtOnboardingRequest(atsign)
          ..rootDomain = AtRootDomain.parse('root.atsign.org');

        var response = await AuthService().onboard(
          onboardingRequest,
          cramSecret,
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
          );
          App.log('Failed to activate ${entry.atsign}'.loggable);
        }
      } catch (e) {
        App.log('Exception activating ${entry.atsign}: $e'.loggable);
        currentEntries[i] = entry.copyWith(
          activationKeyStatus: ActivationKeyStatus.failed,
        );
      }

      // Emit final state for this iteration
      emit(
        state.copyWith(
          fileContent: state.fileContent.copyWith(
            entries: List.from(currentEntries),
          ),
        ),
      );
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
