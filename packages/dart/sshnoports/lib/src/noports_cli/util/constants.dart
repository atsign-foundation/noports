class RegexGroupNames {
  static final atsign = 'atsign';
  static final cram = 'secret';
  static final otp = 'otp';
  static final device = 'device_name';
  static final keyfilePath = 'keyfile_path';
}

final int enrollmentCheckInterval = 3000;

final defaultAppName = 'noports';
final defaultCurrentNamespace = 'noports';
final defaultEnrollmentNamespaces = {
  'sshnp': 'rw',
  'sshrvd': 'rw',
  'noports': 'rw'
};
