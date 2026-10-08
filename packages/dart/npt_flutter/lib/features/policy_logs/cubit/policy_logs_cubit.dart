import 'dart:async';

import 'package:npt_flutter/features/logging/models/loggable.dart';
import '../../logging/models/logging_bloc.dart';
import '../services/policy_log_monitor_service.dart';

part 'policy_logs_state.dart';

class PolicyLogsCubit extends LoggingCubit<PolicyLogsState> {
  final PolicyLogMonitorService _monitorService = PolicyLogMonitorService.getInstance();
  StreamSubscription<PolicyLogEntry>? _logSubscription;

  PolicyLogsCubit() : super(const PolicyLogsState()) {
    _initializeState();
    _listenToLogStream();
  }

  void _initializeState() {
    emit(state.copyWith(
      logs: _monitorService.logs,
      isMonitoring: _monitorService.isMonitoring,
    ));
  }

  void _listenToLogStream() {
    _logSubscription = _monitorService.logStream.listen((logEntry) {
      emit(state.copyWith(
        logs: _monitorService.logs,
      ));
    });
  }

  Future<void> startGlobalMonitoring() async {
    await _monitorService.startGlobalMonitoring();
    emit(state.copyWith(
      isMonitoring: _monitorService.isMonitoring,
      logs: _monitorService.logs,
    ));
  }

  Future<void> stopMonitoring() async {
    await _monitorService.stopMonitoring();
    emit(state.copyWith(
      isMonitoring: _monitorService.isMonitoring,
    ));
  }

  void clearLogs() {
    _monitorService.clearLogs();
    emit(state.copyWith(
      logs: _monitorService.logs,
    ));
  }

  @override
  Future<void> close() {
    _logSubscription?.cancel();
    return super.close();
  }
}