import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

class MultiActivationFileContent {
  final List<ActivationKeyPair> entries;
  // set file name when user uploads file, so that we can display it in the UI
  final String fileName;

  MultiActivationFileContent({required this.entries, required this.fileName});

  /// Parse from YAML data
  factory MultiActivationFileContent.fromYaml(
    Map<dynamic, dynamic> yaml,
    String fileName,
  ) {
    final atsignsList = (yaml['atsigns'] as List<dynamic>).cast<String>();
    final entries = atsignsList
        .map((entry) => ActivationKeyPair.parse(entry))
        .toList();
    App.log('Parsed ${entries.length} entries from YAML'.loggable);
    return MultiActivationFileContent(entries: entries, fileName: fileName);
  }

  /// Convert to JSON
  List<Map<String, dynamic>> toJson() {
    return entries.map((e) => e.toJson()).toList();
  }

  copyWith({List<ActivationKeyPair>? entries, String? fileName}) {
    return MultiActivationFileContent(
      entries: entries ?? this.entries,
      fileName: fileName ?? this.fileName,
    );
  }
}

enum ActivationKeyStatus {
  waiting,
  activating,
  activated,
  alreadyActivated,
  failed,
}

extension ActivationKeyStatusExtension on ActivationKeyStatus {
  String get name {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    switch (this) {
      case ActivationKeyStatus.waiting:
        return strings.activationKeyStatusWaiting;
      case ActivationKeyStatus.activating:
        return strings.activationKeyStatusActivating;
      case ActivationKeyStatus.activated:
        return strings.activationKeyStatusActivated;
      case ActivationKeyStatus.alreadyActivated:
        return strings.activationKeyStatusAlreadyActivated;
      case ActivationKeyStatus.failed:
        return strings.activationKeyStatusFailed;
    }
  }
}

class ActivationKeyPair {
  final String atsign;
  final String activationKey;
  final ActivationKeyStatus activationKeyStatus;

  ActivationKeyPair({
    required this.atsign,
    required this.activationKey,
    required this.activationKeyStatus,
  });

  /// Parse activation atsign list entry string like "@alice01_np:activation_key:9e3246878952e67..."
  factory ActivationKeyPair.parse(String entry) {
    final parts = entry.split(':');
    if (parts.length < 3) {
      throw FormatException('Invalid activation entry format: $entry');
    }

    final atsign = parts[0]; // @alice01_np
    final activationKey = parts
        .sublist(2)
        .single; // Everything after "activation_key:"

    return ActivationKeyPair(
      atsign: atsign,
      activationKey: activationKey,
      activationKeyStatus: ActivationKeyStatus.waiting,
    );
  }

  Map<String, dynamic> toJson() {
    return {'atsign': atsign, 'activationKey': activationKey};
  }

  ActivationKeyPair copyWith({
    String? atsign,
    String? activationKey,
    ActivationKeyStatus? activationKeyStatus,
  }) {
    return ActivationKeyPair(
      atsign: atsign ?? this.atsign,
      activationKey: activationKey ?? this.activationKey,
      activationKeyStatus: activationKeyStatus ?? this.activationKeyStatus,
    );
  }
}
