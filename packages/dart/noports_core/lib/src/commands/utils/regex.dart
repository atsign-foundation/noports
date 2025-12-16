/// Regular expressions for parsing noports command arguments.
class ActivateRegex {
  // CRAM authentication: <atsign>:cram:<secret>
  static final cram = RegExp(r'^(?<atsign>[^:]+):cram:(?<secret>.+)$');

  // Enrollment: <atsign>:enroll:otp:<otp>[:name:<device>:keyfile:<path>]
  static final enroll = RegExp(
    r'^(?<atsign>[^:]+):enroll:otp:(?<otp>[A-Za-z0-9]{6})'
    r'(?:\[:name:(?<device_name>[^:\]]+))?'
    r'(?::?keyfile:(?<keyfile_path>[^\]]+))?\]?$',
  );
}

/// Named capture groups used in noports command regexes.
class ActivateRegexGroups {
  static const atsign = 'atsign';
  static const cram = 'secret';
  static const otp = 'otp';
  static const deviceName = 'device_name';
  static const keyfilePath = 'keyfile_path';
}
