import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/platform/service_manager.dart';

enum ServiceAction { none, start, stop, restart, install }

class ServiceCubitState extends Equatable {
  const ServiceCubitState({
    this.status,
    this.busy = ServiceAction.none,
    this.logs = '',
    this.loadingLogs = false,
    this.error,
    this.elevated,
    this.lastRefreshed,
  });

  final ServiceStatus? status;
  final ServiceAction busy;
  final String logs;
  final bool loadingLogs;
  final String? error;

  /// null until checked.
  final bool? elevated;
  final DateTime? lastRefreshed;

  bool get isBusy => busy != ServiceAction.none;

  ServiceCubitState copyWith({
    ServiceStatus? status,
    ServiceAction? busy,
    String? logs,
    bool? loadingLogs,
    String? error,
    bool? elevated,
    DateTime? lastRefreshed,
    bool clearError = false,
  }) => ServiceCubitState(
    status: status ?? this.status,
    busy: busy ?? this.busy,
    logs: logs ?? this.logs,
    loadingLogs: loadingLogs ?? this.loadingLogs,
    error: clearError ? null : error ?? this.error,
    elevated: elevated ?? this.elevated,
    lastRefreshed: lastRefreshed ?? this.lastRefreshed,
  );

  @override
  List<Object?> get props => [
    status,
    busy,
    logs,
    loadingLogs,
    error,
    elevated,
    lastRefreshed,
  ];
}

/// Tracks and controls the daemon service. Polls status while the app is
/// open so the Status tab stays live.
class ServiceCubit extends Cubit<ServiceCubitState> {
  ServiceCubit(this._manager, {this.pollInterval = const Duration(seconds: 4)})
    : super(const ServiceCubitState());

  final ServiceManager _manager;
  final Duration pollInterval;
  Timer? _timer;

  ServiceManager get manager => _manager;

  Future<void> init() async {
    final elevated = await _manager.isElevated();
    emit(state.copyWith(elevated: elevated));
    await refresh();
    await loadLogs();
    _timer ??= Timer.periodic(pollInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final s = await _manager.status();
      emit(state.copyWith(status: s, lastRefreshed: DateTime.now()));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> loadLogs() async {
    emit(state.copyWith(loadingLogs: true));
    try {
      final logs = await _manager.recentLogs();
      emit(state.copyWith(logs: logs, loadingLogs: false));
    } catch (e) {
      emit(state.copyWith(logs: e.toString(), loadingLogs: false));
    }
  }

  Future<bool> start() => _run(ServiceAction.start, _manager.start);
  Future<bool> stop() => _run(ServiceAction.stop, _manager.stop);
  Future<bool> restart() => _run(ServiceAction.restart, _manager.restart);

  /// Write the service definition (and load it). macOS only for now.
  Future<bool> install() => _run(ServiceAction.install, _manager.install);

  Future<bool> _run(ServiceAction action, Future<void> Function() fn) async {
    if (state.isBusy) return false;
    emit(state.copyWith(busy: action, clearError: true));
    try {
      await fn();
      return true;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return false;
    } finally {
      emit(state.copyWith(busy: ServiceAction.none));
      await refresh();
      await loadLogs();
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
