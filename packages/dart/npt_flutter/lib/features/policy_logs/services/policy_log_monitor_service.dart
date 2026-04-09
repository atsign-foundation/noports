import 'dart:async';
import 'dart:convert';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:npt_flutter/app.dart';

class PolicyLogEntry {
  final String timestamp;
  final Atsign? fromAtsign;
  final Atsign? toAtsign;
  final String type;
  final String deviceName;
  final String deviceGroup;
  final String allowedServices;
  final String? policyPayload;

  PolicyLogEntry({
    required this.timestamp,
    required this.fromAtsign,
    required this.toAtsign,
    required this.type,
    required this.deviceName,
    required this.deviceGroup,
    required this.allowedServices,
    this.policyPayload,
  });

  factory PolicyLogEntry.fromNotification(AtNotification notification) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      notification.epochMillis ?? DateTime.now().millisecondsSinceEpoch,
    );

    String deviceName = '';
    String deviceGroup = '';
    String allowedServices = '';
    String type = 'heartbeat';
    String? policyPayload;

    if (notification.key.contains('logs.policy.sshnp')) {
      type = 'policy request';
      policyPayload = notification.value;

      if (notification.value != null && notification.value!.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(notification.value!);

          final payload = data['payload'];
          if (payload is Map<String, dynamic>) {
            final request = payload['request'];
            if (request is Map<String, dynamic>) {
              final requestPayload = request['payload'];
              if (requestPayload is Map<String, dynamic>) {
                deviceName = requestPayload['daemonDeviceName'] ?? 'unknown';
                deviceGroup = requestPayload['daemonDeviceGroupName'] ?? '';
                final clientAtsign =
                    requestPayload['clientAtsign'] ?? 'unknown';
                final daemonAtsign =
                    requestPayload['daemonAtsign'] ?? 'unknown';
                allowedServices = 'Request: $clientAtsign → $daemonAtsign';
              }
            }
            final response = payload['response'];
            if (response is Map<String, dynamic>) {
              final responsePayload = response['payload'];
              if (responsePayload is Map<String, dynamic>) {
                final authorized = responsePayload['authorized'] ?? false;
                final message = responsePayload['message'] ?? '';
                final permitOpen = responsePayload['permitOpen'];
                String authStatus = authorized ? 'AUTHORIZED' : 'DENIED';
                String permits = '';
                if (permitOpen is List && permitOpen.isNotEmpty) {
                  permits = ' - Permit: ${permitOpen.join(', ')}';
                }
                allowedServices = '$allowedServices ($authStatus$permits)';
              }
            }
          }
        } catch (e) {
          App.log(
            '[ERROR] PolicyLogEntry.fromNotification: Failed to parse policy log payload: $e'
                .loggable,
          );
          allowedServices = 'Parse error: ${e.toString()}';
        }
      }
    } else {
      if (notification.value != null && notification.value!.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(notification.value!);
          deviceName = data['devicename'] ?? 'unknown';
          deviceGroup = data['deviceGroupName'] ?? '';
          if (data['allowedServices'] != null &&
              data['allowedServices'] is List) {
            final List<String> services = List<String>.from(
              data['allowedServices'],
            );
            allowedServices = services.join(', ');
          }
        } catch (e) {
          App.log(
            '[ERROR] PolicyLogEntry.fromNotification: Failed to parse device log payload: $e'
                .loggable,
          );
          final keyParts = notification.key.split(':');
          if (keyParts.length > 1) {
            final devicePart = keyParts[1].split('.devices.policy.sshnp')[0];
            deviceName = devicePart;
          }
          allowedServices = 'Parse error: ${e.toString()}';
        }
      }
    }

    return PolicyLogEntry(
      timestamp: timestamp.toString().substring(0, 19),
      fromAtsign: notification.from.toAtsign(),
      toAtsign: notification.to.toAtsign(),
      type: type,
      deviceName: deviceName,
      deviceGroup: deviceGroup,
      allowedServices: allowedServices,
      policyPayload: policyPayload,
    );
  }
}

class PolicyLogMonitorService {
  static PolicyLogMonitorService? _instance;
  StreamSubscription<AtNotification>? _subscription;
  final StreamController<PolicyLogEntry> _logStreamController =
      StreamController<PolicyLogEntry>.broadcast();
  final List<PolicyLogEntry> _logs = [];
  bool _isMonitoring = false;

  static PolicyLogMonitorService getInstance() {
    return _instance ??= PolicyLogMonitorService._();
  }

  PolicyLogMonitorService._();

  Stream<PolicyLogEntry> get logStream => _logStreamController.stream;
  List<PolicyLogEntry> get logs => List.unmodifiable(_logs);
  bool get isMonitoring => _isMonitoring;

  Future<void> startMonitoring(List<String> deviceNames) async {
    if (_isMonitoring) {
      await stopMonitoring();
    }

    if (deviceNames.isEmpty) {
      return;
    }

    try {
      final AtClient atClient = AtClientManager.getInstance().atClient;

      final deviceRegexParts = deviceNames
          .map((device) => '$device\\.devices\\.policy\\.sshnp')
          .toList();
      final deviceRegex = deviceRegexParts.isNotEmpty
          ? '(${deviceRegexParts.join('|')})'
          : '';
      const policyLogRegex = 'logs\\.policy\\.sshnp';

      final monitorRegex = deviceRegex.isNotEmpty
          ? '($deviceRegex|$policyLogRegex)'
          : policyLogRegex;

      var notificationService = atClient.notificationService;

      _subscription = notificationService
          .subscribe(regex: monitorRegex, shouldDecrypt: true)
          .listen(
            (notification) {
              final logEntry = PolicyLogEntry.fromNotification(notification);
              _logs.insert(0, logEntry);

              if (_logs.length > 100) {
                _logs.removeRange(100, _logs.length);
              }
              _logStreamController.add(logEntry);
            },
            onError: (error) {
              App.log(
                '[ERROR] PolicyLogMonitorService.startMonitoring stream error: $error'
                    .loggable,
              );
              unawaited(stopMonitoring());
            },
            onDone: () {
              App.log(
                '[INFO] PolicyLogMonitorService.startMonitoring stream closed'
                    .loggable,
              );
              unawaited(stopMonitoring());
            },
          );

      _isMonitoring = true;
    } catch (error) {
      App.log(
        '[ERROR] PolicyLogMonitorService.startMonitoring failed: $error'
            .loggable,
      );
      _subscription?.cancel();
      _subscription = null;
      _isMonitoring = false;
    }
  }

  Future<void> startGlobalMonitoring() async {
    if (_isMonitoring) {
      await stopMonitoring();
    }

    try {
      final AtClient atClient = AtClientManager.getInstance().atClient;

      const deviceRegex = r'[^:]*\.devices\.policy\.sshnp';
      const policyLogRegex = 'logs\\.policy\\.sshnp';

      const monitorRegex = '($deviceRegex|$policyLogRegex)';

      var notificationService = atClient.notificationService;

      _subscription = notificationService
          .subscribe(regex: monitorRegex, shouldDecrypt: true)
          .listen(
            (notification) {
              final logEntry = PolicyLogEntry.fromNotification(notification);
              _logs.insert(0, logEntry);

              if (_logs.length > 100) {
                _logs.removeRange(100, _logs.length);
              }

              _logStreamController.add(logEntry);
            },
            onError: (error) {
              App.log(
                '[ERROR] PolicyLogMonitorService.startGlobalMonitoring stream error: $error'
                    .loggable,
              );
              unawaited(
                stopMonitoring(),
              ); // unawait so it tells analyzer that we're intentionally unawaiting
            },
            onDone: () {
              App.log(
                '[INFO] PolicyLogMonitorService.startGlobalMonitoring stream closed'
                    .loggable,
              );
              unawaited(
                stopMonitoring(),
              ); // unawait so it tells naalyzer that we're intentionally unawaiting
            },
          );

      _isMonitoring = true;
    } catch (error) {
      App.log(
        '[ERROR] PolicyLogMonitorService.startGlobalMonitoring failed: $error'
            .loggable,
      );
      _subscription?.cancel();
      _subscription = null;
      _isMonitoring = false;
    }
  }

  Future<void> stopMonitoring() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    _isMonitoring = false;
  }

  void clearLogs() {
    _logs.clear();
  }

  void addLog(PolicyLogEntry entry) {
    _logs.add(entry);
    _logStreamController.add(entry);
  }

  void dispose() {
    stopMonitoring();
    _logStreamController.close();
    _instance = null;
  }
}
