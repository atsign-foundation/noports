import 'dart:io';

import 'package:noports_config/platform/privileged_runner.dart';
import 'package:noports_config/platform/service_manager.dart';

/// A POSIX account: numeric uid and the name systemd's `User=` wants.
typedef PosixUser = ({int uid, String name});

/// systemd control for the sshnpd unit installed by universal.sh or the
/// deb/rpm packages.
class LinuxServiceManager extends ServiceManager {
  LinuxServiceManager({
    this.serviceName = 'sshnpd',
    PrivilegedRunner? runner,
    String? dropInDir,
    PosixUser? appUser,
    int? Function()? unitUid,
  }) : _runner = runner,
       _dropInDir = dropInDir,
       _appUser = appUser,
       _unitUid = unitUid;

  @override
  final String serviceName;
  final PrivilegedRunner? _runner;
  final String? _dropInDir;
  final PosixUser? _appUser;
  final int? Function()? _unitUid;
  PrivilegedRunner get runner => _runner ?? PrivilegedRunner.instance;

  /// Where `systemctl edit sshnpd` keeps its override, and where the
  /// noports package ships `override.conf` with `User=1000`.
  String get dropInDir =>
      _dropInDir ?? '/etc/systemd/system/$serviceName.service.d';

  /// The person using this app, seeing through sudo.
  PosixUser get appUser => _appUser ?? currentUser();

  /// The uid the unit runs as now: null when systemd cannot be asked.
  int? unitUid() => _unitUid != null ? _unitUid() : _unitUidOf(serviceName);

  @override
  String get logSourceDescription => 'journalctl -u $serviceName';

  @override
  Future<ServiceStatus> status() async {
    final result = await Process.run('systemctl', [
      'show',
      serviceName,
      '-p',
      'LoadState,ActiveState,SubState,MainPID,ExecMainStatus,UnitFileState',
    ]);
    final props = <String, String>{};
    for (final line in result.stdout.toString().split('\n')) {
      final i = line.indexOf('=');
      if (i > 0) props[line.substring(0, i)] = line.substring(i + 1).trim();
    }
    if (result.exitCode != 0 || props['LoadState'] == 'not-found') {
      return const ServiceStatus.notInstalled();
    }
    final active = props['ActiveState'];
    final state = switch (active) {
      'active' => ServiceState.running,
      'activating' || 'reloading' => ServiceState.starting,
      'deactivating' => ServiceState.stopping,
      'inactive' || 'failed' => ServiceState.stopped,
      _ => ServiceState.unknown,
    };
    final pid = int.tryParse(props['MainPID'] ?? '');
    final exit = int.tryParse(props['ExecMainStatus'] ?? '');
    return ServiceStatus(
      state: state,
      startType: props['UnitFileState'],
      pid: pid == 0 ? null : pid,
      exitCode: exit == 0 ? null : exit,
      detail: '$active (${props['SubState']})',
    );
  }

  @override
  Future<void> start() async {
    await runner.runShell(_withAdoption('systemctl start $serviceName'));
    final s = await waitFor((s) => !s.isTransitioning);
    if (!s.isRunning) {
      throw ServiceException(
        'Unit did not become active (${s.detail}). Check the log below.',
      );
    }
  }

  @override
  Future<void> stop() async {
    await runner.runShell('systemctl stop $serviceName');
    await waitFor((s) => s.state == ServiceState.stopped);
  }

  @override
  Future<void> restart() async {
    await runner.runShell(privilegedRestartScript);
    final s = await waitFor((s) => !s.isTransitioning);
    if (!s.isRunning) {
      throw ServiceException(
        'Unit did not come back up (${s.detail}). Check the log below.',
      );
    }
  }

  /// `systemctl restart` starts a stopped unit too, so one line covers
  /// both the first start and later restarts. Where the unit still runs
  /// as another account, the same call first makes it run as this user.
  @override
  String get privilegedRestartScript =>
      _withAdoption('systemctl restart $serviceName');

  /// The daemon runs as its unit's `User=`, and that account is the one
  /// whose `~/.atsign/keys` it reads and whose `~/.ssh/authorized_keys` it
  /// adds session keys to, so it has to be the person who enrolled here.
  /// The noports package ships `User=1000` as a placeholder; universal.sh
  /// replaces it with the user who ran the install, and this does the same
  /// for the user running the app. Null when the unit already runs as
  /// that account or systemd cannot be asked.
  @override
  String? get adoptedUser {
    final unit = unitUid();
    if (unit == null || unit == appUser.uid) return null;
    return appUser.name;
  }

  /// Shell that sets `User=` in `override.conf` under [dropInDir] (editing
  /// an existing `User=` line in place, as universal.sh does, or adding
  /// one) and reloads systemd. Empty when there is nothing to change.
  String adoptUserScript() {
    if (adoptedUser == null) return '';
    final dir = PrivilegedRunner.q(dropInDir);
    final file = PrivilegedRunner.q('$dropInDir/override.conf');
    final user = _systemdUser(appUser);
    // No `sed -i`: GNU and BSD differ, and writing through `cat >` keeps
    // the file's owner and mode.
    return 'mkdir -p $dir && '
        "if [ -f $file ] && grep -q '^User=' $file; then "
        'tmp=\$(mktemp) && '
        "sed 's/^User=.*/User=$user/' $file > \"\$tmp\" && "
        'cat "\$tmp" > $file && rm -f "\$tmp"; else '
        "printf '[Service]\\nUser=%s\\n' '$user' >> $file; fi";
  }

  String _withAdoption(String command) {
    final adopt = adoptUserScript();
    if (adopt.isEmpty) return command;
    return '$adopt && systemctl daemon-reload && $command';
  }

  /// A name systemd and the shell both take as-is; otherwise the uid.
  static String _systemdUser(PosixUser u) =>
      RegExp(r'^[a-z_][a-z0-9_-]{0,31}$').hasMatch(u.name)
      ? u.name
      : '${u.uid}';

  /// The account running this process, or the one behind sudo.
  static PosixUser currentUser() {
    final env = Platform.environment;
    final sudo = env['SUDO_USER'];
    if (sudo != null && sudo.isNotEmpty && sudo != 'root') {
      final uid = int.tryParse(env['SUDO_UID'] ?? '') ?? _uidOf(sudo);
      if (uid != null) return (uid: uid, name: sudo);
    }
    final name = _out('id', ['-un']) ?? env['USER'] ?? 'root';
    final uid = int.tryParse(_out('id', ['-u']) ?? '') ?? 0;
    return (uid: uid, name: name);
  }

  /// The unit's `User=` as a uid: root when unset, null when systemctl is
  /// not there to ask.
  static int? _unitUidOf(String unit) {
    final user = _out('systemctl', ['show', unit, '-p', 'User', '--value']);
    if (user == null) return null;
    if (user.isEmpty || user == 'root') return 0;
    return int.tryParse(user) ?? _uidOf(user);
  }

  static int? _uidOf(String name) {
    final line = _out('getent', ['passwd', name]);
    final parts = line?.split(':');
    return parts != null && parts.length > 2 ? int.tryParse(parts[2]) : null;
  }

  static String? _out(String exe, List<String> args) {
    try {
      final r = Process.runSync(exe, args);
      if (r.exitCode != 0) return null;
      return r.stdout.toString().trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> recentLogs({int lines = 200}) async {
    final result = await Process.run('journalctl', [
      '-u',
      serviceName,
      '-n',
      '$lines',
      '--no-pager',
      '-o',
      'short-iso',
    ]);
    final out = result.stdout.toString().trim();
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      return 'Could not read the journal${err.isEmpty ? '' : ': $err'}.\n'
          'Add yourself to the systemd-journal group, or run: journalctl -u $serviceName';
    }
    return out.isEmpty ? 'No journal entries for $serviceName.' : out;
  }

  @override
  Future<bool> isElevated() => runner.isAvailable();
}
