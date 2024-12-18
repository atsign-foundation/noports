import 'dart:async';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_services.dart' show AtKeysFileUploadService, FileUploadStatus;
import 'package:at_server_status/at_server_status.dart';

// These types are returned from methods in this class so exports are provided for ease of use
export 'package:at_onboarding_flutter/at_onboarding_services.dart' show FileUploadStatus;
export 'package:at_server_status/at_server_status.dart' show AtStatus;

class NoPortsOnboardingUtil {
  /// The upload service will be created when the first time [uploadAtKeysFile] is called
  AtKeysFileUploadService? _uploadService;
  AtServerStatus? _atServerStatus;
  AtOnboardingConfig config;
  NoPortsOnboardingUtil(this.config);

  /// A method to check whether an atSign has been activated or not
  Future<AtStatus> atServerStatus(String atSign) async {
    _atServerStatus ??=
        AtStatusImpl(rootUrl: config.atClientPreference.rootDomain, rootPort: config.atClientPreference.rootPort);
    return _atServerStatus!.get(atSign);
  }

  /// Upload an atKeys file, returning a stream with the progress so we can update the ui accordingly.
  /// Example implementation:
  /// https://github.com/atsign-foundation/at_widgets/blob/b4006854fa93c21eeb5bcea41044787bdf0f6f32/packages/at_onboarding_flutter/lib/src/screen/at_onboarding_home_screen.dart#L659
  Stream<FileUploadStatus> uploadAtKeysFile(String? atSign) {
    _uploadService ??= AtKeysFileUploadService(config: config);
    return _uploadService!.uploadKeyFile(atSign);
  }

  // TODO: implement APKAM onboarding
}
