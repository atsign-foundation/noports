import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/config/model/sshnpd_config_document.dart';
import 'package:noports_config/features/health/health_checks.dart';
import 'package:noports_config/features/keys/keys_repository.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/service_manager.dart';

class HealthState extends Equatable {
  const HealthState({
    this.results = const [],
    this.running = false,
    this.doctorOutput,
    this.doctorRunning = false,
    this.error,
  });

  final List<HealthResult> results;
  final bool running;
  final String? doctorOutput;
  final bool doctorRunning;
  final String? error;

  int count(CheckLevel l) => results.where((r) => r.level == l).length;
  bool get allPassed => results.isNotEmpty && count(CheckLevel.fail) == 0;

  HealthState copyWith({
    List<HealthResult>? results,
    bool? running,
    String? doctorOutput,
    bool? doctorRunning,
    String? error,
    bool clearError = false,
  }) => HealthState(
    results: results ?? this.results,
    running: running ?? this.running,
    doctorOutput: doctorOutput ?? this.doctorOutput,
    doctorRunning: doctorRunning ?? this.doctorRunning,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [results, running, doctorOutput, doctorRunning, error];
}

class HealthCubit extends Cubit<HealthState> {
  HealthCubit({
    List<HealthCheck>? checks,
    DaemonPaths? paths,
    ServiceManager? services,
    KeysRepository? keys,
  }) : _checks = checks ?? HealthChecks.all(),
       _paths = paths,
       _services = services,
       _keys = keys ?? KeysRepository(paths: paths),
       super(const HealthState());

  final List<HealthCheck> _checks;
  final DaemonPaths? _paths;
  final ServiceManager? _services;
  final KeysRepository _keys;

  DaemonPaths get paths => _paths ?? DaemonPaths.instance;
  ServiceManager get services => _services ?? ServiceManager.instance;

  /// Runs the in-app checks against the document as it is on disk (not the
  /// unsaved working copy) so the results describe what the daemon sees.
  Future<List<HealthResult>> run() async {
    emit(state.copyWith(running: true, clearError: true, results: const []));
    SshnpdConfigDocument? doc;
    final exists = await paths.configFile.exists();
    if (exists) {
      try {
        doc = SshnpdConfigDocument.parse(await paths.configFile.readAsString());
      } catch (_) {
        doc = null;
      }
    }
    final ctx = HealthContext(
      doc: doc,
      configExists: exists,
      paths: paths,
      services: services,
      keys: _keys,
    );
    final results = <HealthResult>[];
    for (final c in _checks) {
      try {
        results.add(await c.run(ctx));
      } catch (e) {
        results.add(HealthResult(c.title, CheckLevel.fail, 'Check crashed: $e'));
      }
      emit(state.copyWith(results: List.of(results)));
    }
    emit(state.copyWith(running: false));
    return results;
  }

  /// Runs `sshnpd --doctor` and captures its report.
  Future<void> runDoctor() async {
    emit(state.copyWith(doctorRunning: true, clearError: true));
    try {
      final bin = paths.sshnpdBinary;
      final r = await Process.run(
        bin.path,
        ['--doctor'],
        environment: {'SSHNPD_CONFIG': paths.configFile.path},
      ).timeout(const Duration(minutes: 2));
      final out = (r.stdout.toString() + r.stderr.toString()).trim();
      emit(state.copyWith(doctorOutput: out.isEmpty ? '(no output)' : out, doctorRunning: false));
    } catch (e) {
      emit(state.copyWith(doctorRunning: false, error: e.toString()));
    }
  }
}
