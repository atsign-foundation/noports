final cramRegex = RegExp(
  r'(?<atsign>.+:)cram:(?<secret>.+)$',
  caseSensitive: false,
);
final enrollRegex = RegExp(
  r'/(?<atsign>.+:)enroll:otp:(?<otp>.{6})',
  caseSensitive: false,
);