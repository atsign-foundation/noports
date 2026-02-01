part of 'policy_logs_cubit.dart';

final class PolicyLogsState extends Loggable {
  final List<PolicyLogEntry> logs;
  final bool isMonitoring;

  const PolicyLogsState({this.logs = const [], this.isMonitoring = false});

  PolicyLogsState copyWith({List<PolicyLogEntry>? logs, bool? isMonitoring}) {
    return PolicyLogsState(
      logs: logs ?? this.logs,
      isMonitoring: isMonitoring ?? this.isMonitoring,
    );
  }

  @override
  List<Object?> get props => [logs, isMonitoring];

  @override
  String toString() {
    return 'PolicyLogsState(logs: ${logs.length}, isMonitoring: $isMonitoring)';
  }
}
