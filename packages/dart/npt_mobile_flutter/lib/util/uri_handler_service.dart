import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:npt_mobile_flutter/app.dart';

/// Service to handle connection URIs and launch appropriate applications
class UriHandlerService {
  /// Launches the appropriate application for the given URI
  ///
  /// Supports:
  /// - http/https: Opens in default browser
  /// - rdp: Launches RDP client
  /// - ssh: Launches SSH client
  /// - vnc: Launches VNC client
  /// - Custom protocols handled by the OS
  static Future<bool> handleUri(String? uriString) async {
    if (uriString == null || uriString.trim().isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse(uriString.trim());

      // Handle different URI schemes
      switch (uri.scheme.toLowerCase()) {
        case 'http':
        case 'https':
          return await _launchUrl(uri);

        case 'rdp':
          return await _launchRdp(uri);

        case 'ssh':
          return await _launchSsh(uri);

        case 'vnc':
          return await _launchVnc(uri);

        default:
          // Try to launch using the OS default handler
          return await _launchUrl(uri);
      }
    } catch (e) {
      App.log('Error handling URI "$uriString": $e'.loggable);
      return false;
    }
  }

  /// Launches a URL in the default browser
  static Future<bool> _launchUrl(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      App.log('Cannot launch URL: $uri'.loggable);
      return false;
    } catch (e) {
      App.log('Error launching URL "$uri": $e'.loggable);
      return false;
    }
  }

  /// Launches RDP client with the given URI
  static Future<bool> _launchRdp(Uri uri) async {
    try {
      String host = uri.host;
      int port = uri.hasPort ? uri.port : 3389;

      App.log('Launching RDP: $host:$port'.loggable);

      if (Platform.isWindows) {
        // Windows: Use mstsc (Microsoft Terminal Services Client)
        final result = await Process.run('mstsc', ['/v:$host:$port']);
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        // macOS: Try to launch rdp:// URI with system handler
        final rdpUri = Uri(scheme: 'rdp', host: host, port: port);
        if (await canLaunchUrl(rdpUri)) {
          App.log('Launching RDP URI: $rdpUri'.loggable);
          return await launchUrl(rdpUri, mode: LaunchMode.externalApplication);
        }

        App.log('No RDP handler found on macOS'.loggable);
        return false;
      } else if (Platform.isLinux) {
        // Linux: Try xfreerdp, rdesktop, or other RDP clients
        try {
          final result = await Process.run('xfreerdp', [
            '/v:$host:$port',
            '/cert:ignore',
          ]);
          return result.exitCode == 0;
        } catch (e) {
          // Try rdesktop as fallback
          try {
            final result = await Process.run('rdesktop', ['$host:$port']);
            return result.exitCode == 0;
          } catch (e) {
            App.log(
              'No RDP client found on Linux. Install xfreerdp or rdesktop.'
                  .loggable,
            );
            return false;
          }
        }
      }
      return false;
    } catch (e) {
      App.log('Error launching RDP client: $e'.loggable);
      return false;
    }
  }

  /// Launches SSH client with the given URI
  static Future<bool> _launchSsh(Uri uri) async {
    try {
      App.log('Launching SSH URI: $uri'.loggable);

      // Try to launch the ssh:// URI with the system default handler
      if (await canLaunchUrl(uri)) {
        final result = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (result) {
          App.log('SSH URI launched successfully'.loggable);
        } else {
          App.log('SSH URI launch returned false'.loggable);
        }
        return result;
      }

      App.log('Cannot launch SSH URI - no handler available'.loggable);

      // Fallback: construct an ssh command and try to launch Terminal with it
      if (Platform.isMacOS) {
        String host = uri.host;
        int port = uri.hasPort ? uri.port : 22;
        String? user = uri.userInfo.isNotEmpty ? uri.userInfo : null;
        String sshCommand = user != null ? '$user@$host' : host;

        try {
          final result = await Process.run('osascript', [
            '-e',
            'tell application "Terminal" to do script "ssh -p $port $sshCommand"',
          ]);

          if (result.exitCode == 0) {
            App.log('SSH launched via Terminal fallback'.loggable);
            return true;
          } else {
            App.log('Terminal fallback failed: ${result.stderr}'.loggable);
          }
        } catch (e) {
          App.log('Terminal fallback error: $e'.loggable);
        }
      }

      return false;
    } catch (e) {
      App.log('Error launching SSH: $e'.loggable);
      return false;
    }
  }

  /// Launches VNC client with the given URI
  static Future<bool> _launchVnc(Uri uri) async {
    try {
      String host = uri.host;
      int port = uri.hasPort ? uri.port : 5900;

      if (Platform.isWindows) {
        // Try to use TightVNC or other VNC viewer
        final vncUri = Uri(scheme: 'vnc', host: host, port: port);
        if (await canLaunchUrl(vncUri)) {
          return await launchUrl(vncUri, mode: LaunchMode.externalApplication);
        }
      } else if (Platform.isMacOS) {
        // macOS: Use Screen Sharing
        try {
          final result = await Process.run('open', ['vnc://$host:$port']);
          if (result.exitCode == 0) {
            App.log('VNC launched successfully'.loggable);
            return true;
          } else {
            App.log('VNC open command failed: ${result.stderr}'.loggable);
            return false;
          }
        } catch (e) {
          App.log('Error running open command for VNC: $e'.loggable);
          return false;
        }
      } else if (Platform.isLinux) {
        // Linux: Try vncviewer
        final result = await Process.run('vncviewer', ['$host:$port']);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      App.log('Error launching VNC client: $e'.loggable);
      return false;
    }
  }
}
