import 'dart:io';

/// On macOS and Linux the app has to run as root to write the daemon's
/// config directory and drive launchctl / systemctl. When started as a
/// normal user, relaunch through the platform's authorisation prompt and
/// exit. Windows handles this through the requireAdministrator manifest.
///
/// Set NOPORTS_CONFIG_NO_ELEVATE=1 to skip (useful for `flutter run`).
class Elevation {
  Elevation._();

  static Future<void> relaunchAsRootIfNeeded() async {
    if (Platform.isWindows) return;
    if (Platform.environment['NOPORTS_CONFIG_NO_ELEVATE'] == '1') return;
    if (await _isRoot()) return;

    final exe = Platform.resolvedExecutable;
    final env = 'NOPORTS_CONFIG_NO_ELEVATE=1';
    try {
      if (Platform.isMacOS) {
        // The child inherits the user's GUI session, so a root process can
        // still show a window. Run it detached and let this one exit.
        final quoted = exe.replaceAll('"', r'\"');
        final script =
            'do shell script "$env \\"$quoted\\" >/dev/null 2>&1 &" '
            'with administrator privileges';
        final r = await Process.run('osascript', ['-e', script]);
        if (r.exitCode != 0) {
          // User cancelled the prompt or osascript failed: carry on
          // unprivileged; the UI explains the limitation.
          return;
        }
        exit(0);
      }
      if (Platform.isLinux) {
        final display = Platform.environment['DISPLAY'] ?? '';
        final xauth = Platform.environment['XAUTHORITY'] ?? '';
        final wayland = Platform.environment['WAYLAND_DISPLAY'] ?? '';
        final runtime = Platform.environment['XDG_RUNTIME_DIR'] ?? '';
        await Process.start(
          'pkexec',
          [
            'env',
            env,
            'DISPLAY=$display',
            'XAUTHORITY=$xauth',
            'WAYLAND_DISPLAY=$wayland',
            'XDG_RUNTIME_DIR=$runtime',
            exe,
          ],
          mode: ProcessStartMode.detached,
        );
        exit(0);
      }
    } on ProcessException {
      // No osascript / pkexec available; run unprivileged.
    }
  }

  static Future<bool> _isRoot() async {
    try {
      final r = await Process.run('id', ['-u']);
      return r.stdout.toString().trim() == '0';
    } catch (_) {
      return false;
    }
  }
}
