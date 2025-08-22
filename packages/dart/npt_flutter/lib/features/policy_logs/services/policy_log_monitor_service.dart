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
  final String? policyPayload;

  PolicyLogEntry({
    required this.timestamp,
    required this.fromAtSign,
    required this.toAtSign,
    required this.type,
    required this.deviceName,
    required this.deviceGroup,
    required this.allowedServices,
    this.policyPayload,
  });

  factory PolicyLogEntry.fromNotification(AtNotification notification) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(notification.epochMillis ?? DateTime.now().millisecondsSinceEpoch);
    
    String deviceName = 'unknown';
    String deviceGroup = '';
    String allowedServices = '';
    String type = 'heartbeat';
    String? policyPayload;
    
    // Check if this is a policy request notification
    if (notification.key.contains('logs.policy.sshnp')) {
      type = 'policy request';
      policyPayload = notification.value; // Store the entire JSON payload
      
      // Try to parse the payload to extract device info for display
      if (notification.value != null && notification.value!.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(notification.value!);
          
          // Extract device info from the nested payload structure
          final payload = data['payload'];
          if (payload is Map<String, dynamic>) {
            final request = payload['request'];
            if (request is Map<String, dynamic>) {
              final requestPayload = request['payload'];
              if (requestPayload is Map<String, dynamic>) {
                deviceName = requestPayload['daemonDeviceName'] ?? 'unknown';
                deviceGroup = requestPayload['daemonDeviceGroupName'] ?? '';
                
                // Show request info in allowed services field
                final clientAtSign = requestPayload['clientAtsign'] ?? 'unknown';
                final daemonAtSign = requestPayload['daemonAtsign'] ?? 'unknown';
                allowedServices = 'Request: $clientAtSign → $daemonAtSign';
              }
            }
            
            // Also check response for additional info
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
          allowedServices = 'Parse error: ${e.toString()}';
        }
      }
    } else {
      // Handle regular heartbeat notifications
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
    }

    return PolicyLogEntry(
      timestamp: timestamp.toString().substring(0, 19), // Format: 2024-01-15 10:30:15
      fromAtSign: notification.from ?? 'unknown',
      toAtSign: notification.to ?? 'unknown',
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
      
      // Create regex for monitoring both device-specific policy keys and policy request logs
      // Pattern 1: @*:deviceName.devices.policy.sshnp@* (device heartbeats)
      // Pattern 2: @*:logs.policy.sshnp@* (policy requests)
      final deviceRegexParts = deviceNames.map((device) => '$device\\.devices\\.policy\\.sshnp').toList();
      final deviceRegex = deviceRegexParts.isNotEmpty ? '(${deviceRegexParts.join('|')})' : '';
      const policyLogRegex = 'logs\\.policy\\.sshnp';
      
      // Combine both patterns
      final monitorRegex = deviceRegex.isNotEmpty ? '($deviceRegex|$policyLogRegex)' : policyLogRegex;

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
          // Handle errors silently for now
        },
        onDone: () {
          // Handle stream closure
        }
      );

      _isMonitoring = true;
      
    } catch (error) {
      // Handle errors silently for now
    }
  }

  Future<void> startGlobalMonitoring() async {
    if (_isMonitoring) {
      await stopMonitoring();
    }

    try {
      final AtClient atClient = AtClientManager.getInstance().atClient;
      
      // Monitor both heartbeats and policy request logs globally
      // Pattern 1: @*:*.devices.policy.sshnp@* (all device heartbeats)
      // Pattern 2: @*:logs.policy.sshnp@* (policy requests)
      const deviceRegex = r'[^:]*\.devices\.policy\.sshnp';
      const policyLogRegex = 'logs\\.policy\\.sshnp';
      
      // Combine both patterns to capture heartbeats AND policy requests
      const monitorRegex = '($deviceRegex|$policyLogRegex)';

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
          // Handle errors silently for now
        },
        onDone: () {
          // Handle stream closure
        }
      );

      _isMonitoring = true;
      
    } catch (error) {
      // Handle errors silently for now
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