import 'dart:convert';
import 'dart:typed_data';

import 'package:noports_core/src/common/validation_utils.dart';

/// The `authorized_keys` option that begins every line sshnpd adds for a
/// client's key, allowing logins only from the device's loopback address.
const String loopbackFromOption = 'from="127.0.0.1,::1"';

/// A client's ssh public key, checked and ready to be written to
/// `authorized_keys` as one line.
class AuthorizedPublicKey {
  /// The longest value [AuthorizedPublicKey.parse] accepts, in UTF-8 bytes.
  static const int maxValueBytes = 8192;

  /// The longest comment kept on the line.
  static const int maxCommentLength = 256;

  /// Each key type accepted, mapped to the type its key data must name.
  static const Map<String, String> keyDataTypes = {
    'ssh-ed25519': 'ssh-ed25519',
    'ssh-rsa': 'ssh-rsa',
    'rsa-sha2-256': 'ssh-rsa',
    'rsa-sha2-512': 'ssh-rsa',
    'ecdsa-sha2-nistp256': 'ecdsa-sha2-nistp256',
    'ecdsa-sha2-nistp384': 'ecdsa-sha2-nistp384',
    'ecdsa-sha2-nistp521': 'ecdsa-sha2-nistp521',
  };

  AuthorizedPublicKey._(
    this.type,
    this.keyData,
    this.comment,
    this.commentLeftOut,
  );

  /// The key type written to the line, which is the type its key data names.
  final String type;

  /// The key data, in base64.
  final String keyData;

  /// The comment written to the line, if any.
  final String? comment;

  /// Whether the value's comment was left out, holding a character outside
  /// ASCII or being longer than [maxCommentLength].
  final bool commentLeftOut;

  static final RegExp _base64 = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');

  /// Parses `<type> <base64>[ <comment>]`, throwing a [FormatException] that
  /// says why when the value is refused.
  factory AuthorizedPublicKey.parse(String value) {
    if (utf8.encode(value).length > maxValueBytes) {
      throw FormatException('it is over $maxValueBytes bytes');
    }
    final String trimmed = _trimAsciiWhitespace(value);
    if (trimmed.runes.any(_breaksLines)) {
      throw const FormatException('it holds a control character');
    }
    final List<String> fields = trimmed.split(' ');
    if (fields.length < 2) {
      throw const FormatException('it is not "<type> <key data>"');
    }
    final String? dataType = keyDataTypes[fields[0]];
    if (dataType == null) {
      throw const FormatException('its key type is not one sshnpd accepts');
    }
    final String keyData = fields[1];
    if (_keyDataType(keyData) != dataType) {
      throw const FormatException('its key data is not of its stated key type');
    }
    final String? comment = fields.length > 2 ? fields.skip(2).join(' ') : null;
    final bool keep = comment == null || _isKeptComment(comment);
    return AuthorizedPublicKey._(
      dataType,
      keyData,
      keep ? comment : null,
      !keep,
    );
  }

  /// The `authorized_keys` line for this key: [loopbackFromOption], then
  /// each of [permissions] trimmed, leaving empty ones out, then the key,
  /// ending in a newline. Throws an [ArgumentError] when [permissions] hold
  /// a CR, an LF or a `from` option.
  String line({String permissions = ''}) {
    if (RegExp(r'[\r\n]').hasMatch(permissions)) {
      throw ArgumentError(invalidSshKeyPermissionsMsg);
    }
    final kept = sshKeyPermissionsLeavingOutFrom(permissions);
    if (kept.fromLeftOut) {
      throw ArgumentError(sshKeyPermissionsFromMsg);
    }
    final String options = kept.permissions.isEmpty
        ? loopbackFromOption
        : '$loopbackFromOption,${kept.permissions}';
    final String suffix = comment == null ? '' : ' $comment';
    return '$options $type $keyData$suffix\n';
  }

  static String? _keyDataType(String keyData) {
    if (keyData.length % 4 != 0 || !_base64.hasMatch(keyData)) {
      return null;
    }
    final Uint8List bytes;
    try {
      bytes = base64.decode(keyData);
    } on FormatException {
      return null;
    }
    if (bytes.length < 4) {
      return null;
    }
    final int length = ByteData.sublistView(bytes, 0, 4).getUint32(0);
    if (length > bytes.length - 4) {
      return null;
    }
    return latin1.decode(bytes.sublist(4, 4 + length));
  }

  static bool _isKeptComment(String comment) =>
      comment.length <= maxCommentLength &&
      comment.codeUnits.every((c) => c >= 0x20 && c <= 0x7e);
}

/// The key data on an `authorized_keys` line, read as sshd reads it: the
/// token after a supported key type, with any options before that type.
/// Null for a blank line, a `#` line, or one with no supported key type
/// where sshd looks for one.
({String keyData, bool loopbackOnly})? authorizedKeysLineKey(String line) {
  String rest = _trimLeadingBlanks(line);
  if (rest.isEmpty || rest.startsWith('#')) {
    return null;
  }
  String options = '';
  if (!AuthorizedPublicKey.keyDataTypes.containsKey(_firstToken(rest))) {
    final int end = _endOfOptions(rest);
    options = rest.substring(0, end);
    rest = _trimLeadingBlanks(rest.substring(end));
  }
  final List<String> tokens = rest.split(RegExp(r'[ \t]+'));
  if (tokens.length < 2 ||
      !AuthorizedPublicKey.keyDataTypes.containsKey(tokens[0])) {
    return null;
  }
  return (
    keyData: tokens[1],
    loopbackOnly: _options(
      options,
    ).any((o) => o.trim().toLowerCase() == loopbackFromOption),
  );
}

/// [permissions], a comma-separated list of `authorized_keys` options, with
/// each option trimmed and every empty or `from` option left out, matching
/// `from` in any case and treating commas inside double quotes as part of an
/// option; [fromLeftOut] says whether a `from` option was left out.
({String permissions, bool fromLeftOut}) sshKeyPermissionsLeavingOutFrom(
  String permissions,
) {
  bool fromLeftOut = false;
  final List<String> kept = [];
  for (final String option in _options(permissions)) {
    final String trimmed = option.trim();
    if (trimmed.split('=').first.trim().toLowerCase() == 'from') {
      fromLeftOut = true;
    } else if (trimmed.isNotEmpty) {
      kept.add(trimmed);
    }
  }
  return (permissions: kept.join(','), fromLeftOut: fromLeftOut);
}

/// [value] fit for one log line, cut to at most [maxLength] characters
/// without splitting an escape: each UTF-8 byte of it outside printable
/// ASCII, and each `"` and `\`, shown escaped as `\n`, `\r`, `\t`, `\xNN`,
/// `\"` or `\\`.
String oneLineForLog(String value, {int maxLength = 200}) {
  final StringBuffer out = StringBuffer();
  int length = 0;
  for (final int byte in utf8.encode(value)) {
    final String shown = _shownInLog(byte);
    if (length + shown.length > maxLength) {
      break;
    }
    out.write(shown);
    length += shown.length;
  }
  return out.toString();
}

String _shownInLog(int byte) => switch (byte) {
  0x0a => r'\n',
  0x0d => r'\r',
  0x09 => r'\t',
  0x22 => r'\"',
  0x5c => r'\\',
  _ when byte >= 0x20 && byte <= 0x7e => String.fromCharCode(byte),
  _ => '\\x${byte.toRadixString(16).padLeft(2, '0')}',
};

bool _breaksLines(int rune) =>
    rune < 0x20 ||
    rune == 0x7f ||
    rune == 0x85 ||
    rune == 0x2028 ||
    rune == 0x2029;

/// [options] split on each comma outside double quotes, as sshd splits them,
/// where `\"` inside a quoted value does not end it.
List<String> _options(String options) {
  final List<String> split = [];
  final StringBuffer option = StringBuffer();
  bool quoted = false;
  for (int i = 0; i < options.length; i++) {
    final String c = options[i];
    if (c == r'\' && i + 1 < options.length && options[i + 1] == '"') {
      option.write(r'\"');
      i++;
    } else if (c == '"') {
      quoted = !quoted;
      option.write(c);
    } else if (c == ',' && !quoted) {
      split.add(option.toString());
      option.clear();
    } else {
      option.write(c);
    }
  }
  split.add(option.toString());
  return split;
}

/// Where the options at the start of [line] end: at the first space or tab
/// outside double quotes, where `\"` does not end a quoted value.
int _endOfOptions(String line) {
  bool quoted = false;
  int i = 0;
  for (; i < line.length; i++) {
    final String c = line[i];
    if (!quoted && (c == ' ' || c == '\t')) {
      break;
    }
    if (c == r'\' && i + 1 < line.length && line[i + 1] == '"') {
      i++;
    } else if (c == '"') {
      quoted = !quoted;
    }
  }
  return i;
}

String _firstToken(String line) => line.split(RegExp(r'[ \t]')).first;

String _trimLeadingBlanks(String line) {
  int start = 0;
  while (start < line.length && (line[start] == ' ' || line[start] == '\t')) {
    start++;
  }
  return line.substring(start);
}

String _trimAsciiWhitespace(String value) {
  const String whitespace = ' \t\n\r\v\f';
  int start = 0;
  int end = value.length;
  while (start < end && whitespace.contains(value[start])) {
    start++;
  }
  while (end > start && whitespace.contains(value[end - 1])) {
    end--;
  }
  return value.substring(start, end);
}
