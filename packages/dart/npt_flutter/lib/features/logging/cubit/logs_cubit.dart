import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';

/// This is the only Cubit in the app which should *not* extend the
/// [LoggingCubit] type, it will cause infinite recursion of [log]
class LogsCubit extends Cubit<List<LogEntry>> {
  LogsCubit() : super([]);

  void log(Loggable loggable) {
    var enabled = App.navState.currentContext?.read<EnableLoggingCubit>().state;
    if (enabled != null && enabled) {
      emit(state..add(LogEntry(loggable)));
    }
  }

  List<LogEntry> get logs => state;
}
