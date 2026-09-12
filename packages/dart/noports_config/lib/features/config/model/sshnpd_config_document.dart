import 'package:noports_config/platform/atsigns.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_core/sshnpd.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// An sshnpd.yaml file held as text.
///
/// Edits go through yaml_edit so the comments and layout of the shipped
/// template survive a save. Values are read back by parsing the current
/// text, so this class never holds a second copy of the data that could
/// drift from the file.
class SshnpdConfigDocument {
  SshnpdConfigDocument.parse(String yaml) : _editor = YamlEditor(yaml) {
    // Fail early on malformed input.
    loadYaml(yaml);
  }

  final YamlEditor _editor;

  String get source => _editor.toString();

  YamlNode get _root => _editor.parseAt([]);

  /// The whole document as plain Dart collections (maps, lists, scalars).
  Map<String, dynamic> asMap() {
    final root = _root.value;
    return root is Map ? _plain(root) as Map<String, dynamic> : {};
  }

  static dynamic _plain(dynamic node) {
    if (node is YamlMap || node is Map) {
      return <String, dynamic>{
        for (final e in (node as Map).entries) e.key.toString(): _plain(e.value),
      };
    }
    if (node is YamlList || node is List) {
      return (node as List).map(_plain).toList();
    }
    return node;
  }

  /// Value at [path], or null when any segment is missing or null.
  dynamic get(List<String> path) {
    dynamic cur = asMap();
    for (final key in path) {
      if (cur is! Map || !cur.containsKey(key)) return null;
      cur = cur[key];
    }
    return cur;
  }

  /// Sets [path] to [value], creating intermediate maps as needed.
  /// Passing null, an empty string or an empty list clears the value while
  /// keeping the key in place, matching the style of the template.
  void set(List<String> path, Object? value) {
    if (value is String && value.isEmpty) value = null;
    if (value is List && value.isEmpty) value = null;
    if (path.isEmpty) throw ArgumentError('path must not be empty');

    // Walk down while the existing nodes are maps; stop at the first
    // segment that is missing or not a map.
    var depth = 0;
    dynamic cur = _root.value;
    while (depth < path.length && cur is Map && cur.containsKey(path[depth])) {
      final next = cur[path[depth]];
      if (depth == path.length - 1 || next is! Map) break;
      cur = next;
      depth++;
    }

    if (cur is! Map) {
      // Parent exists but is a scalar (e.g. `access:` with no children).
      // Replace it with a map built from the remaining path.
      _editor.update(path.sublist(0, depth), _nest(path.sublist(depth), value));
      return;
    }

    if (cur.containsKey(path[depth])) {
      if (depth == path.length - 1) {
        _editor.update(path, value);
      } else {
        // Existing key whose value is not a map (null or scalar): replace
        // the value with the nested remainder.
        _editor.update(
          path.sublist(0, depth + 1),
          _nest(path.sublist(depth + 1), value),
        );
      }
    } else {
      // Key missing from an existing map: insert the nested remainder.
      _editor.update(
        path.sublist(0, depth + 1),
        _nest(path.sublist(depth + 1), value),
      );
    }
  }

  static Object? _nest(List<String> rest, Object? value) {
    if (rest.isEmpty) return value;
    return {rest.first: _nest(rest.sublist(1), value)};
  }

  // Typed accessors for the handful of values the app itself needs.

  String? get atsign => _string(SshnpdOption.atsign);
  set atsign(String? v) => setOption(SshnpdOption.atsign, _formatAtsign(v));

  String? get keysFile => _string(SshnpdOption.keyfile);
  set keysFile(String? v) => setOption(SshnpdOption.keyfile, v);

  String get rootDomain =>
      _string(SshnpdOption.rootServer) ?? 'root.atsign.org';

  List<String> get managers => _list(SshnpdOption.managers);
  set managers(List<String> v) =>
      setOption(SshnpdOption.managers, v.map(_formatAtsign).toList());

  String? get policyManager => _string(SshnpdOption.policyManager);
  set policyManager(String? v) =>
      setOption(SshnpdOption.policyManager, _formatAtsign(v));

  List<String> get permitOpen => _list(SshnpdOption.permitOpen);
  set permitOpen(List<String> v) => setOption(SshnpdOption.permitOpen, v);

  String? get deviceName => _string(SshnpdOption.device);
  set deviceName(String? v) => setOption(SshnpdOption.device, v);

  String? get deviceGroup => _string(SshnpdOption.deviceGroup);
  set deviceGroup(String? v) => setOption(SshnpdOption.deviceGroup, v);

  /// True when the file has never been filled in.
  bool get isUnconfigured => (atsign ?? '').trim().isEmpty;

  dynamic getOption(SshnpdOption o) => get(ConfigSchema.byOption(o).path);

  void setOption(SshnpdOption o, Object? value) =>
      set(ConfigSchema.byOption(o).path, value);

  String? _string(SshnpdOption o) {
    final v = getOption(o);
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  List<String> _list(SshnpdOption o) {
    final v = getOption(o);
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (v is String && v.trim().isNotEmpty) {
      return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  /// Adds the '@' when the value is a plausible atSign; leaves anything
  /// else untouched so validation can report it instead of throwing.
  static String? _formatAtsign(String? v) {
    if (v == null) return null;
    final t = v.trim();
    if (t.isEmpty) return null;
    return Atsigns.normalize(t) ?? t;
  }

  /// Problems that would stop the daemon starting or make it unreachable.
  /// Empty means the file is good to save and run.
  List<ConfigProblem> validate() {
    final problems = <ConfigProblem>[];
    final a = atsign;
    if (a == null) {
      problems.add(ConfigProblem(SshnpdOption.atsign, 'A device atSign is required.'));
    } else if (!isValidAtsign(a)) {
      problems.add(ConfigProblem(SshnpdOption.atsign, '"$a" is not a valid atSign.'));
    }
    for (final m in managers) {
      if (!isValidAtsign(m)) {
        problems.add(ConfigProblem(SshnpdOption.managers, '"$m" is not a valid atSign.'));
      }
    }
    final pm = policyManager;
    if (pm != null && !isValidAtsign(pm)) {
      problems.add(ConfigProblem(SshnpdOption.policyManager, '"$pm" is not a valid atSign.'));
    }
    if (managers.isEmpty && pm == null) {
      problems.add(ConfigProblem(
        SshnpdOption.managers,
        'Add at least one manager atSign or a policy atSign, otherwise nobody can connect.',
      ));
    }
    for (final po in permitOpen) {
      if (!isValidPermitOpen(po)) {
        problems.add(ConfigProblem(
          SshnpdOption.permitOpen,
          '"$po" must be host:port, or *:* for everything.',
        ));
      }
    }
    final port = getOption(SshnpdOption.localSshdPort);
    if (port != null) {
      final n = port is int ? port : int.tryParse(port.toString());
      if (n == null || n < 1 || n > 65535) {
        problems.add(ConfigProblem(SshnpdOption.localSshdPort, 'Port must be between 1 and 65535.'));
      }
    }
    final dn = deviceName;
    if (dn != null && !RegExp(r'^[a-zA-Z0-9_-]{1,36}$').hasMatch(dn)) {
      problems.add(ConfigProblem(
        SshnpdOption.device,
        'Device name may only contain letters, numbers, underscore and dash (max 36).',
      ));
    }
    return problems;
  }

  static bool isValidAtsign(String s) => Atsigns.isValid(s);

  static bool isValidPermitOpen(String s) {
    final t = s.trim();
    if (t == '*:*') return true;
    final i = t.lastIndexOf(':');
    if (i <= 0 || i == t.length - 1) return false;
    final port = t.substring(i + 1);
    if (port == '*') return true;
    final n = int.tryParse(port);
    return n != null && n >= 1 && n <= 65535;
  }
}

class ConfigProblem {
  const ConfigProblem(this.option, this.message);
  final SshnpdOption option;
  final String message;

  @override
  String toString() => message;
}
