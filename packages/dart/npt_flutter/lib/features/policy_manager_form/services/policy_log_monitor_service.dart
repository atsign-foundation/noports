import 'dart:async';

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
}

class PolicyLogMonitorService {
  static PolicyLogMonitorService? _instance;
  
  static PolicyLogMonitorService getInstance() {
    _instance ??= PolicyLogMonitorService._internal();
    return _instance!;
  }
  
  PolicyLogMonitorService._internal();

  final List<PolicyLogEntry> _logs = [];
  final StreamController<PolicyLogEntry> _logStreamController = StreamController<PolicyLogEntry>.broadcast();
  bool _isMonitoring = false;

  List<PolicyLogEntry> get logs => List.unmodifiable(_logs);
  Stream<PolicyLogEntry> get logStream => _logStreamController.stream;
  bool get isMonitoring => _isMonitoring;

  Future<void> startGlobalMonitoring() async {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    // TODO: Implement actual monitoring logic
    // This is a placeholder for the real monitoring implementation
  }

  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    // TODO: Implement stopping logic
  }

  void clearLogs() {
    _logs.clear();
  }

  void addLog(PolicyLogEntry entry) {
    _logs.add(entry);
    _logStreamController.add(entry);
  }

  void dispose() {
    _logStreamController.close();
  }
}