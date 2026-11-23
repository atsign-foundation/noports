import 'dart:convert';
import 'dart:typed_data';

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

  /// Whether the value's comment was left out, being longer than
  /// [maxCommentLength] or not printable ASCII.
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
      throw FormatException('its key data is not of type ${fields[0]}');
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
  /// [permissions] when there are any, then the key, ending in a newline.
  String line({String permissions = ''}) {
    final String options = permissions.isEmpty
        ? loopbackFromOption
        : '$loopbackFromOption,$permissions';
    final String suffix = comment == null ? '' : ' $comment';
    return '$options $type $keyData$suffix\n';
  }

  static String? _keyDataType(String keyData) {
    if (keyData.length % 4 != 0 || !_base64.hasMatch(keyData)) {
      return null;
    }
    final Uint8List bytes = base64.decode(keyData);
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

/// Whether [permissions], a comma-separated list of `authorized_keys`
/// options, holds a `from` option, matching its name in any case and
/// treating commas inside double quotes as part of an option.
bool sshKeyPermissionsHoldFrom(String permissions) {
  final List<String> names = [];
  final StringBuffer option = StringBuffer();
  bool quoted = false;
  for (int i = 0; i < permissions.length; i++) {
    final String c = permissions[i];
    if (c == r'\' && i + 1 < permissions.length && permissions[i + 1] == '"') {
      option.write(r'\"');
      i++;
    } else if (c == '"') {
      quoted = !quoted;
      option.write(c);
    } else if (c == ',' && !quoted) {
      names.add(option.toString());
      option.clear();
    } else {
      option.write(c);
    }
  }
  names.add(option.toString());
  return names.any((o) => o.split('=').first.trim().toLowerCase() == 'from');
}

/// [value] fit for one log line: each control character, and each of
/// U+0085, U+2028 and U+2029, shown escaped, and cut to at most [maxLength]
/// characters.
String oneLineForLog(String value, {int maxLength = 200}) {
  final StringBuffer out = StringBuffer();
  int length = 0;
  for (final int rune in value.runes) {
    final String shown = _breaksLines(rune)
        ? _escape(rune)
        : String.fromCharCode(rune);
    final int shownLength = shown.runes.length;
    if (length + shownLength > maxLength) {
      break;
    }
    out.write(shown);
    length += shownLength;
  }
  return out.toString();
}

bool _breaksLines(int rune) =>
    rune < 0x20 ||
    rune == 0x7f ||
    rune == 0x85 ||
    rune == 0x2028 ||
    rune == 0x2029;

String _escape(int rune) => switch (rune) {
  0x0a => r'\n',
  0x0d => r'\r',
  0x09 => r'\t',
  _ when rune < 0x100 => '\\x${rune.toRadixString(16).padLeft(2, '0')}',
  _ => '\\u${rune.toRadixString(16).padLeft(4, '0')}',
};

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
