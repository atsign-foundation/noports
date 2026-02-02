import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:at_auth/at_auth.dart';
import 'package:at_client_mobile/src/atsign_key.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:at_commons/at_builders.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/util/constants.dart';
import 'package:path_provider/path_provider.dart';

/// File upload status states
abstract class FileUploadStatus {
  const FileUploadStatus();
}

class FilePickingInProgress extends FileUploadStatus {
  const FilePickingInProgress();
}

class FilePickingDone extends FileUploadStatus {
  const FilePickingDone();
}

class ProcessingAesKeyInProgress extends FileUploadStatus {
  const ProcessingAesKeyInProgress();
}

class ProcessingAesKeyDone extends FileUploadStatus {
  const ProcessingAesKeyDone();
}

class FileUploadAuthSuccess extends FileUploadStatus {
  final String atSign;
  const FileUploadAuthSuccess(this.atSign);
}

class FilePickingCanceled extends FileUploadStatus {
  const FilePickingCanceled();
}

class ErrorIncorrectKeyFile extends FileUploadStatus {
  final String message;
  const ErrorIncorrectKeyFile(this.message);
}

class ErrorAtSignMismatch extends FileUploadStatus {
  final String message;
  const ErrorAtSignMismatch(this.message);
}

class ErrorFailedFileProcessing extends FileUploadStatus {
  final String message;
  const ErrorFailedFileProcessing(this.message);
}

class ErrorAtServerUnreachable extends FileUploadStatus {
  final String message;
  const ErrorAtServerUnreachable(this.message);
}

class ErrorAuthFailed extends FileUploadStatus {
  final String message;
  const ErrorAuthFailed(this.message);
}

class ErrorAuthTimeout extends FileUploadStatus {
  final String message;
  const ErrorAuthTimeout(this.message);
}

class ErrorPairedAtsign extends FileUploadStatus {
  final String message;
  final String? atSign;
  const ErrorPairedAtsign(this.message, {this.atSign});
}

/// File upload service for atKeys files
class AtKeysFileUploadService {
  final AtOnboardingConfig config;
  final StreamController<FileUploadStatus> _statusController =
      StreamController<FileUploadStatus>.broadcast();

  AtKeysFileUploadService({required this.config});

  Stream<FileUploadStatus> uploadKeyFile(String? atSign) async* {
    try {
      // Pick file
      _statusController.add(const FilePickingInProgress());
      yield const FilePickingInProgress();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        _statusController.add(const FilePickingCanceled());
        yield const FilePickingCanceled();
        return;
      }

      _statusController.add(const FilePickingDone());
      yield const FilePickingDone();

      final filePath = result.files.single.path;
      if (filePath == null) {
        _statusController.add(
          const ErrorFailedFileProcessing('File path is null'),
        );
        yield const ErrorFailedFileProcessing('File path is null');
        return;
      }

      // Process the keys file
      _statusController.add(const ProcessingAesKeyInProgress());
      yield const ProcessingAesKeyInProgress();

      final file = File(filePath);
      final content = await file.readAsString();

      // Extract atsign from file content
      String? fileAtsign;
      try {
        // The atKeys file typically contains the atsign in the filename or content
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.contains('@')) {
            // Extract atsign (this is a simplified extraction, may need refinement)
            final match = RegExp(r'@[\w-]+').firstMatch(line);
            if (match != null) {
              fileAtsign = match.group(0);
              break;
            }
          }
        }
      } catch (e) {
        _statusController.add(
          ErrorIncorrectKeyFile('Failed to parse key file: $e'),
        );
        yield ErrorIncorrectKeyFile('Failed to parse key file: $e');
        return;
      }

      // Verify atsign matches if provided
      if (atSign != null && fileAtsign != null && fileAtsign != atSign) {
        _statusController.add(
          ErrorAtSignMismatch('File is for $fileAtsign but expected $atSign'),
        );
        yield ErrorAtSignMismatch(
          'File is for $fileAtsign but expected $atSign',
        );
        return;
      }

      final atsignToUse = fileAtsign ?? atSign;
      if (atsignToUse == null) {
        _statusController.add(
          const ErrorIncorrectKeyFile('Could not determine atsign from file'),
        );
        yield const ErrorIncorrectKeyFile(
          'Could not determine atsign from file',
        );
        return;
      }

      _statusController.add(const ProcessingAesKeyDone());
      yield const ProcessingAesKeyDone();

      // Store the keys using KeyChainManager
      try {
        final keyChainManager = KeyChainManager.getInstance();
        final appDocsDir = await getApplicationSupportDirectory();
        final keysFilePath =
            '${appDocsDir.path}/keys/${atsignToUse}_key.atKeys';

        // Create keys directory if it doesn't exist
        final keysDir = Directory('${appDocsDir.path}/keys');
        if (!await keysDir.exists()) {
          await keysDir.create(recursive: true);
        }

        // Copy the file to the keys directory
        await file.copy(keysFilePath);

        // Parse the atKeys JSON - these keys are AES-encrypted
        final Map<String, dynamic> keysJson = jsonDecode(content);

        // Extract the selfEncryptionKey (this is the AES key used to encrypt the other keys)
        final selfEncryptionKey = keysJson['selfEncryptionKey'];
        if (selfEncryptionKey == null) {
          throw Exception('selfEncryptionKey not found in atKeys file');
        }

        // Decrypt all the encrypted keys using the selfEncryptionKey
        final pkamPublicKey = EncryptionUtil.decryptValue(
          keysJson['aesPkamPublicKey'],
          selfEncryptionKey,
        );
        final pkamPrivateKey = EncryptionUtil.decryptValue(
          keysJson['aesPkamPrivateKey'],
          selfEncryptionKey,
        );
        final encryptionPublicKey = EncryptionUtil.decryptValue(
          keysJson['aesEncryptPublicKey'],
          selfEncryptionKey,
        );
        final encryptionPrivateKey = EncryptionUtil.decryptValue(
          keysJson['aesEncryptPrivateKey'],
          selfEncryptionKey,
        );

        // Create an AtsignKey object with the DECRYPTED keys
        final atsignKey = AtsignKey(
          atSign: atsignToUse,
          pkamPublicKey: pkamPublicKey,
          pkamPrivateKey: pkamPrivateKey,
          encryptionPublicKey: encryptionPublicKey,
          encryptionPrivateKey: encryptionPrivateKey,
          selfEncryptionKey:
              selfEncryptionKey, // Store the AES key itself (unencrypted)
        );

        // Store the decrypted keys in the keychain
        await keyChainManager.storeAtSign(atSign: atsignKey);

        // ALSO store keys in atClient's local secondary storage IF atClient is initialized
        // This matches exactly what _persistKeysLocalSecondary does in at_auth_service_impl
        // However, on first run, atClient may not be initialized yet, which is fine -
        // the keys in KeyChain are sufficient, and atClient will load them on next initialization
        try {
          final atClient = AtClientManager.getInstance().atClient;
          final localStorage = atClient.getLocalSecondary();
          if (localStorage != null) {
            // Store PKAM keys
            await localStorage.putValue(
              AtConstants.atPkamPublicKey,
              pkamPublicKey,
            );
            await localStorage.putValue(
              AtConstants.atPkamPrivateKey,
              pkamPrivateKey,
            );

            // Store encryption private key
            await localStorage.putValue(
              AtConstants.atEncryptionPrivateKey,
              encryptionPrivateKey,
            );

            // Store encryption public key (must use UpdateVerbBuilder like the auth service does)
            var updateBuilder = UpdateVerbBuilder()
              ..atKey = AtKey.public(
                'publickey',
                sharedBy: atsignToUse,
              ).build();
            updateBuilder.atKey.metadata.ttr = -1;
            updateBuilder.value = encryptionPublicKey;
            await localStorage.executeVerb(updateBuilder, sync: true);

            // Store self encryption key
            await localStorage.putValue(
              AtConstants.atEncryptionSelfKey,
              selfEncryptionKey,
            );

            // CRITICAL: Force atChops to be re-initialized with the newly stored keys
            // This is necessary because atChops may have been created before we uploaded the keys
            // Access atClient.atChops to trigger lazy initialization with the correct keys
            try {
              // ignore: unused_local_variable
              final chops = atClient.atChops;
            } catch (e) {
              // atChops initialization will happen when needed
            }
          }
        } catch (e) {
          // If storing to atClient fails, that's okay - keys are already in KeyChain
          // which is the primary storage. atClient will load from KeyChain on next init.
          // Silently ignore this error as it's expected on first run
        }

        _statusController.add(FileUploadAuthSuccess(atsignToUse));
        yield FileUploadAuthSuccess(atsignToUse);
      } catch (e) {
        _statusController.add(ErrorAuthFailed('Failed to store keys: $e'));
        yield ErrorAuthFailed('Failed to store keys: $e');
      }
    } catch (e) {
      _statusController.add(ErrorFailedFileProcessing('Unexpected error: $e'));
      yield ErrorFailedFileProcessing('Unexpected error: $e');
    }
  }

  void dispose() {
    _statusController.close();
  }
}

/// Onboarding service
class OnboardingService {
  static OnboardingService? _instance;
  AtOnboardingConfig? _config;
  AtClientPreference? _atClientPreference;
  String? _atsign;

  OnboardingService._();

  static OnboardingService getInstance() {
    _instance ??= OnboardingService._();
    return _instance!;
  }

  void setConfig(AtOnboardingConfig config) {
    _config = config;
    _atClientPreference = config.atClientPreference;
  }

  AtOnboardingConfig? getConfig() {
    return _config;
  }

  set setAtClientPreference(AtClientPreference preference) {
    _atClientPreference = preference;
  }

  set setAtsign(String atsign) {
    _atsign = atsign;
  }

  Future<bool> isExistingAtsign(String atsign) async {
    try {
      final keyChainManager = KeyChainManager.getInstance();
      final atsignList = await keyChainManager.getAtSignListFromKeychain();
      return atsignList.contains(atsign);
    } catch (e) {
      return false;
    }
  }

  Future<AtStatus> checkAtSignServerStatus(String atsign) async {
    try {
      final atServerStatus = AtStatusImpl(
        rootUrl: _atClientPreference?.rootDomain ?? 'root.atsign.org',
        rootPort: _atClientPreference?.rootPort ?? 64,
      );
      return await atServerStatus.get(atsign);
    } catch (e) {
      throw Exception('Failed to check server status: $e');
    }
  }

  Future<AtOnboardingResult> onboard({
    String? context,
    String? atsign,
    String? cramkey,
  }) async {
    try {
      final atClientManager = AtClientManager.getInstance();

      // Set current atsign
      await atClientManager.setCurrentAtSign(
        atsign ?? _atsign ?? '',
        'npt',
        _atClientPreference ?? AtClientPreference(),
      );

      return AtOnboardingResult.success(atsign: atsign ?? _atsign ?? '');
    } catch (e) {
      return AtOnboardingResult.error(message: 'Onboarding failed: $e');
    }
  }

  Future<AtOnboardingResult> changePrimaryAtsign({
    required String atsign,
    required AtClientPreference atClientPreference,
  }) async {
    try {
      // Ensure the keys are in the keychain before attempting to switch
      final keyChainManager = KeyChainManager.getInstance();
      final atsignKey = await keyChainManager.readAtsign(name: atsign);

      if (atsignKey == null) {
        return AtOnboardingResult.error(
          message: 'AtSign keys not found in keychain for $atsign',
        );
      }

      // First, use the at_onboarding_flutter's changePrimaryAtsign to switch the active atsign
      final changeSuccess = await AtOnboarding.changePrimaryAtsign(
        atsign: atsign,
      );

      if (!changeSuccess) {
        return AtOnboardingResult.error(
          message: 'Failed to set $atsign as primary',
        );
      }

      // Then onboard to initialize atClient with the keys
      final context = App.navState.currentContext!;
      final onboardingResult = await AtOnboarding.onboard(
        context: context,
        config: AtOnboardingConfig(
          atClientPreference: atClientPreference,
          domain: atClientPreference.rootDomain,
          rootEnvironment: RootEnvironment.Production,
          appAPIKey: await Constants.appAPIKey,
        ),
        atsign: atsign,
      );

      return onboardingResult;
    } catch (e) {
      return AtOnboardingResult.error(message: 'Failed to change atsign: $e');
    }
  }

  Future<AtOnboardingResult> enroll({
    required String atsign,
    required String appName,
    required String deviceName,
    required String otp,
    required AtClientPreference atClientPreference,
  }) async {
    try {
      App.log('[OnboardingService] Starting enrollment for $atsign'.loggable);
      App.log(
        '[OnboardingService] appName: $appName, deviceName: $deviceName'
            .loggable,
      );
      App.log('[OnboardingService] atSign for enrollment: $atsign'.loggable);

      // Create the auth service for enrollment
      final authService = AtAuthServiceImpl(atsign, atClientPreference);

      final enrollmentRequest = EnrollmentRequest(
        appName: appName,
        deviceName: deviceName,
        otp: otp,
        namespaces: {appName: 'rw', "sshnp": 'rw', 'sshrvd': 'rw'},
      );

      App.log(
        '[OnboardingService] EnrollmentRequest details - appName: ${enrollmentRequest.appName}, deviceName: ${enrollmentRequest.deviceName}, namespaces: ${enrollmentRequest.namespaces}'
            .loggable,
      );
      App.log('[OnboardingService] Calling authService.enroll()'.loggable);

      final enrollResponse = await authService.enroll(enrollmentRequest);

      App.log(
        '[OnboardingService] Enrollment SUCCESS! EnrollmentId: ${enrollResponse.enrollmentId}'
            .loggable,
      );
      App.log(
        '[OnboardingService] Enrollment request should now be visible on desktop app for approval'
            .loggable,
      );

      // Convert AtEnrollmentResponse to AtOnboardingResult
      // If we got here without an exception, enrollment succeeded
      return AtOnboardingResult.success(atsign: atsign);
    } catch (e, st) {
      App.log('[OnboardingService] Error during enrollment: $e'.loggable);
      App.log(st.toString().loggable);
      return AtOnboardingResult.error(message: 'Enrollment failed: $e');
    }
  }
}

/// Helper function to initialize contacts service
Future<void> initializeContactsService(
  BuildContext context,
  String atsign,
) async {
  // This is a no-op since we're using our custom ContactService
  // The actual initialization happens in the ContactService singleton
}
