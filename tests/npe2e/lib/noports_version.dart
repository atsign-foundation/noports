import 'package:npe2e/language.dart';
import 'package:version/version.dart';

class NoPortsVersion {
  final Language language;
  final String
  version; // "current", "v5.9.4", "v5.11.2", "v5.13.0", "trunk" "$commitHash"

  NoPortsVersion({required this.language, required this.version});

  factory NoPortsVersion.fromLanguageVersionString(final String s) {
    final List<String> parts = s.split(':');
    if (parts.length != 2) {
      throw Exception('Invalid language version string: $s');
    }
    final String languagePart = parts[0];
    final String versionPart = parts[1];
    return NoPortsVersion(
      language: languageFromString(languagePart),
      version: versionPart,
    );
  }

  // returns '5.9.4', 'current', 'trunk', '0.0.1'
  String getCleanVersionString() {
    if (version.startsWith('v') || version.startsWith('c')) {
      return version.substring(1);
    }
    return version;
  }

  // e.g. 'd:current', 'd:5.9.4', 'c:0.0.1'
  String toLanguageVersionString() {
    final String languageInitial = language.name[0]; // 'd' for dart, 'c' for c
    final String cleanVersionString =
        getCleanVersionString(); // e.g. 'current', '5.9.4', '0.0.1'
    return '$languageInitial:$cleanVersionString';
  }

  operator ==(Object other) {
    if (other is NoPortsVersion) {
      return language == other.language && version == other.version;
    }
    return false;
  }
}

bool versionIsAtLeast(
  NoPortsVersion versionToCheck,
  NoPortsVersion minimumVersion,
) {
  if (versionToCheck.version == 'current') {
    return true; // treat "current" as a very high version for comparison purposes
  }
  if (minimumVersion.version == 'current') {
    return false; // "current" is only greater than versions that are less than "current"
  }

  final String cleanVersionStr = versionToCheck
      .getCleanVersionString(); // e.g. '5.9.4', 'trunk', '0.0.1'
  final String cleanMinimumVersion = minimumVersion
      .getCleanVersionString(); // e.g. '5.9.4', 'trunk', '0.0.1'

  // Parse and compare versions
  final Version version = Version.parse(cleanVersionStr);
  final Version minimumVersionParsed = Version.parse(cleanMinimumVersion);
  return version >= minimumVersionParsed;
}

bool versionIsLessThan(
  NoPortsVersion versionToCheck,
  NoPortsVersion maximumVersion,
) {
  if (versionToCheck.version == 'current') {
    return false; // treat "current" as a very high version for comparison purposes
  }
  if (maximumVersion.version == 'current') {
    return true; // "current" is only greater than versions that are less than "current"
  }

  final String cleanVersionStr = versionToCheck
      .getCleanVersionString(); // e.g. '5.9.4', 'trunk', '0.0.1'
  final String cleanMaximumVersion = maximumVersion
      .getCleanVersionString(); // e.g. '5.9.4', 'trunk', '0.0.1'

  // Parse and compare versions
  final Version version = Version.parse(cleanVersionStr);
  final Version maximumVersionParsed = Version.parse(cleanMaximumVersion);
  return version < maximumVersionParsed;
}
