import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';

class LoggingBloc<E extends Loggable, S extends Loggable> extends Bloc<E, S> {
  LoggingBloc(super.initialState);

  @override
  onEvent(E event) {
    super.onEvent(event);
    App.log(_TriggeredEvent(event));
  }

  @override
  void emit(S state) {
    // ignore: invalid_use_of_visible_for_testing_member
    super.emit(state);
    App.log(_EmittedState(state));
  }
}

class LoggingCubit<S extends Loggable> extends Cubit<S> {
  LoggingCubit(super.initialState);

  @override
  void emit(S state) {
    super.emit(state);
    App.log(_EmittedState(state));
  }
}

class _TriggeredEvent extends Loggable {
  final Loggable loggable;
  const _TriggeredEvent(this.loggable);

  @override
  List<Object> get props => [loggable];

  @override
  String toString() {
    return 'Triggered Event | $loggable';
  }
}

class _EmittedState extends Loggable {
  final Loggable loggable;
  const _EmittedState(this.loggable);

  @override
  List<Object> get props => [loggable];

  @override
  String toString() {
    // 2 extra spaces so it aligns with the triggered event section
    return 'Emitted State   | $loggable';
  }
}
