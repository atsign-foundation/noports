import 'package:flutter/material.dart';
import 'dart:async';
import '../../policy_manager_form/widgets/policy_log_item.dart';
import '../../policy_manager_form/services/policy_log_monitor_service.dart';

class LogsViewer extends StatefulWidget {
  const LogsViewer({super.key});

  @override
  State<LogsViewer> createState() => _LogsViewerState();
}

class _LogsViewerState extends State<LogsViewer> {
  late StreamSubscription<PolicyLogEntry> _logSubscription;
  final PolicyLogMonitorService _monitorService = PolicyLogMonitorService.getInstance();
  List<PolicyLogEntry> _logs = [];
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _logs = _monitorService.logs;
    _isMonitoring = _monitorService.isMonitoring;
    // Listen to new log entries
    _logSubscription = _monitorService.logStream.listen((logEntry) {
      if (mounted) {
        setState(() {
          _logs = _monitorService.logs;
        });
      }
    });
  }

  @override
  void dispose() {
    _logSubscription.cancel();
    super.dispose();
  }

  void _startGlobalMonitoring() async {
    // Start monitoring all policy logs globally
    _monitorService.clearLogs();
    await _monitorService.startGlobalMonitoring();
    setState(() {
      _isMonitoring = _monitorService.isMonitoring;
    });
  }

  void _stopMonitoring() async {
    await _monitorService.stopMonitoring();
    setState(() {
      _isMonitoring = _monitorService.isMonitoring;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status and controls row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isMonitoring ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isMonitoring ? Colors.green.shade300 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isMonitoring ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isMonitoring ? 'Monitoring Active' : 'Monitoring Inactive',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _isMonitoring ? Colors.green.shade700 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (!_isMonitoring)
              ElevatedButton.icon(
                onPressed: _startGlobalMonitoring,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Start Monitoring'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            if (_isMonitoring)
              ElevatedButton.icon(
                onPressed: _stopMonitoring,
                icon: const Icon(Icons.stop, size: 16),
                label: const Text('Stop Monitoring'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                _monitorService.clearLogs();
                setState(() {
                  _logs = [];
                });
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear Logs'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Main logs container
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Timestamp',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w300,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'From atSign',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w300,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'To atSign',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w300,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Log Type',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w300,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Device Name',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w300,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Device Group',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w300,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Allowed Services',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w300,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Logs container
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: _buildLogsList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsList() {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _isMonitoring 
                ? 'No logs available yet.\nActivity will appear here when policy requests are made.'
                : 'No logs available.\nStart monitoring from the Policy Manager to see activity.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return PolicyLogItem(
          timestamp: log.timestamp,
          fromAtSign: log.fromAtSign,
          toAtSign: log.toAtSign,
          type: log.type,
          deviceName: log.deviceName,
          deviceGroup: log.deviceGroup,
          allowedServices: log.allowedServices,
          policyPayload: log.policyPayload,
        );
      },
    );
  }
}