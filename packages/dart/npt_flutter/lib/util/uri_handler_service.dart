import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:npt_flutter/app.dart';

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
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
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
      
      if (Platform.isWindows) {
        // Windows: Use mstsc (Microsoft Terminal Services Client)
        final result = await Process.run(
          'mstsc',
          ['/v:$host:$port'],
        );
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        // macOS: Try to launch Microsoft Remote Desktop or use rdp:// URL
        final rdpUri = Uri(scheme: 'rdp', host: host, port: port);
        if (await canLaunchUrl(rdpUri)) {
          return await launchUrl(
            rdpUri,
            mode: LaunchMode.externalApplication,
          );
        }
        // Fallback: open Microsoft Remote Desktop if installed
        final result = await Process.run(
          'open',
          ['-a', 'Microsoft Remote Desktop', '--args', 'rdp://full%20address=s:$host:$port'],
        );
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        // Linux: Try xfreerdp, rdesktop, or other RDP clients
        try {
          final result = await Process.run(
            'xfreerdp',
            ['/v:$host:$port', '/cert:ignore'],
          );
          return result.exitCode == 0;
        } catch (e) {
          // Try rdesktop as fallback
          try {
            final result = await Process.run(
              'rdesktop',
              ['$host:$port'],
            );
            return result.exitCode == 0;
          } catch (e) {
            App.log('No RDP client found on Linux. Install xfreerdp or rdesktop.'.loggable);
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
      String host = uri.host;
      int port = uri.hasPort ? uri.port : 22;
      String? user = uri.userInfo.isNotEmpty ? uri.userInfo : null;
      
      String sshCommand = user != null ? '$user@$host' : host;
      
      if (Platform.isWindows) {
        // Windows: Launch in new terminal window
        final result = await Process.run(
          'cmd',
          ['/c', 'start', 'ssh', '-p', '$port', sshCommand],
        );
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        // macOS: Launch Terminal with SSH command
        final result = await Process.run(
          'osascript',
          [
            '-e',
            'tell application "Terminal" to do script "ssh -p $port $sshCommand"'
          ],
        );
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        // Linux: Launch in default terminal
        final result = await Process.run(
          'x-terminal-emulator',
          ['-e', 'ssh', '-p', '$port', sshCommand],
        );
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      App.log('Error launching SSH client: $e'.loggable);
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
          return await launchUrl(
            vncUri,
            mode: LaunchMode.externalApplication,
          );
        }
      } else if (Platform.isMacOS) {
        // macOS: Use Screen Sharing
        final result = await Process.run(
          'open',
          ['vnc://$host:$port'],
        );
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        // Linux: Try vncviewer
        final result = await Process.run(
          'vncviewer',
          ['$host:$port'],
        );
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      App.log('Error launching VNC client: $e'.loggable);
      return false;
    }
  }
}
