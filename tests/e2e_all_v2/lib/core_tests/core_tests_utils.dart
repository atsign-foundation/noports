import 'package:e2e_all_v2/language.dart';

// e.g. 'v5.9.4' --> '594', 'c0.0.1' --> '001', 'current' --> 'c'
// '5.9.4' --> '594', '0.0.1' --> '001'
String _versionForDeviceName(final String version) {
  String s;
  if(version == 'current') {
    s = 'c';
    return s;
  }
  // v5.9.4 -> 594
  // c0.0.1 --> 001
  s = version.replaceAll('.', '').replaceAll('v', '').replaceAll('c', '');

  // maximum 6 characters of s
  if(s.length > 6) {
    s = s.substring(0, 6);
  }
  return s;
}

String getDeviceNameNoFlags({
  required final String testRunId,
  required final Language language,
  required final String version}) {
  return '${testRunId}${language.name.substring(0, 1)}${_versionForDeviceName(version)}';
}
