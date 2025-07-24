import 'dart:async';
import 'dart:convert';
import 'package:at_client_mobile/at_client_mobile.dart';

class PolicyLogEntry {
  final String timestamp;
  final String fromAtSign;
  final String toAtSign;
  final String type;
  final String deviceName;
  final String deviceGroup;
  final String allowedServices;

  PolicyLogEntry({
    required this.timestamp,
    required this.fromAtSign,
    required this.toAtSign,
    required this.type,
    required this.deviceName,
    required this.deviceGroup,
    required this.allowedServices,
  });

  factory PolicyLogEntry.fromNotification(AtNotification notification) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(notification.epochMillis ?? DateTime.now().millisecondsSinceEpoch);
    
    String deviceName = 'unknown';
    String deviceGroup = '';
    String allowedServices = '';
    String type = 'heartbeat';
    
    // Parse the JSON value if it exists and is encrypted/decrypted
    if (notification.value != null && notification.value!.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(notification.value!);
        deviceName = data['devicename'] ?? 'unknown';
        deviceGroup = data['deviceGroupName'] ?? '';
        
        // Format allowed services
        if (data['allowedServices'] != null && data['allowedServices'] is List) {
          final List<String> services = List<String>.from(data['allowedServices']);
          allowedServices = services.join(', ');
        }
      } catch (e) {
        // If JSON parsing fails, try to extract device name from key
        final keyParts = notification.key.split(':');
        if (keyParts.length > 1) {
          final devicePart = keyParts[1].split('.devices.policy.sshnp')[0];
          deviceName = devicePart;
        }
              allowedServices = 'Parse error: ${e.toString()}';
      }
    }

    return PolicyLogEntry(
      timestamp: timestamp.toString().substring(0, 19), // Format: 2024-01-15 10:30:15
      fromAtSign: notification.from ?? 'unknown',
      toAtSign: notification.to ?? 'unknown',
      type: type,
      deviceName: deviceName,
      deviceGroup: deviceGroup,
      allowedServices: allowedServices,
    );
  }
}

class PolicyLogMonitorService {
  static PolicyLogMonitorService? _instance;
  StreamSubscription<AtNotification>? _subscription;
  final StreamController<PolicyLogEntry> _logStreamController = StreamController<PolicyLogEntry>.broadcast();
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
      
      // Create regex for monitoring device-specific policy keys
      // Pattern: @*:deviceName.devices.policy.sshnp@*
      final deviceRegexParts = deviceNames.map((device) => '$device\\.devices\\.policy\\.sshnp').toList();
      final monitorRegex = '(${deviceRegexParts.join('|')})';

      // Subscribe to notification stream
      var notificationService = atClient.notificationService;
      
      _subscription = notificationService.subscribe(regex: monitorRegex, shouldDecrypt: true).listen(
        (notification) {
          final logEntry = PolicyLogEntry.fromNotification(notification);
          _logs.insert(0, logEntry); // Add to beginning for newest first
          
          // Keep only last 100 log entries to avoid memory issues
          if (_logs.length > 100) {
            _logs.removeRange(100, _logs.length);
          }
          
          _logStreamController.add(logEntry);
        },
        onError: (error) {
          // final errorEntry = PolicyLogEntry(
          //   timestamp: DateTime.now().toString().substring(0, 19),
          //   fromAtSign: 'system',
          //   toAtSign: 'monitor',
          //   type: 'error',
          //   deviceName: 'monitor',
          //   deviceGroup: '',
          //   allowedServices: 'Monitor error: ${error.toString()}',
          // );
          // _logs.insert(0, errorEntry);
          // _logStreamController.add(errorEntry);
        },
        onDone: () {
          // final doneEntry = PolicyLogEntry(
          //   timestamp: DateTime.now().toString().substring(0, 19),
          //   fromAtSign: 'system',
          //   toAtSign: 'monitor',
          //   type: 'info',
          //   deviceName: 'monitor',
          //   deviceGroup: '',
          //   allowedServices: 'Monitor stream closed',
          // );
          // _logs.insert(0, doneEntry);
          // _logStreamController.add(doneEntry);
          // _isMonitoring = false;
        }
      );

      _isMonitoring = true;

      // Add initial log entry
      // final startEntry = PolicyLogEntry(
      //   timestamp: DateTime.now().toString().substring(0, 19),
      //   fromAtSign: 'system',
      //   toAtSign: 'monitor',
      //   type: 'info',
      //   deviceName: 'monitor',
      //   deviceGroup: '',
      //   allowedServices: 'Started monitoring devices: ${deviceNames.join(', ')}',
      // );
      // _logs.insert(0, startEntry);
      // _logStreamController.add(startEntry);
      
    } catch (error) {
      // final errorEntry = PolicyLogEntry(
      //   timestamp: DateTime.now().toString().substring(0, 19),
      //   fromAtSign: 'system',
      //   toAtSign: 'monitor',
      //   type: 'error',
      //   deviceName: 'monitor',
      //   deviceGroup: '',
      //   allowedServices: 'Failed to start monitoring: ${error.toString()}',
      // );
      // _logs.insert(0, errorEntry);
      // _logStreamController.add(errorEntry);
    }
  }

  Future<void> stopMonitoring() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    _isMonitoring = false;
    
    // Add stop log entry
    if (_logs.isNotEmpty || _isMonitoring) {
      // final stopEntry = PolicyLogEntry(
      //   timestamp: DateTime.now().toString().substring(0, 19),
      //   fromAtSign: 'system',
      //   toAtSign: 'monitor',
      //   type: 'info',
      //   deviceName: 'monitor',
      //   deviceGroup: '',
      //   allowedServices: 'Monitoring stopped',
      // );
      // _logs.insert(0, stopEntry);
      // _logStreamController.add(stopEntry);
    }
  }

  void clearLogs() {
    _logs.clear();
  }

  void dispose() {
    stopMonitoring();
    _logStreamController.close();
    _instance = null;
  }
}