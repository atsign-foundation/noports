import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum HomeTab { status, configuration, keys, diagnostics }

class NavState extends Equatable {
  const NavState({this.tab = HomeTab.status, this.wizard = false, this.decided = false});
  final HomeTab tab;

  /// Show the first-run wizard instead of the tabs.
  final bool wizard;

  /// Whether the "start in the wizard?" decision has been made for this
  /// session. It is made once, when the config first loads, so the wizard
  /// does not disappear the moment the user types an atSign into it.
  final bool decided;

  NavState copyWith({HomeTab? tab, bool? wizard, bool? decided}) => NavState(
    tab: tab ?? this.tab,
    wizard: wizard ?? this.wizard,
    decided: decided ?? this.decided,
  );

  @override
  List<Object?> get props => [tab, wizard, decided];
}

class NavCubit extends Cubit<NavState> {
  NavCubit() : super(const NavState());

  /// Called once when the configuration has loaded.
  void decideInitial({required bool unconfigured}) {
    if (state.decided) return;
    emit(state.copyWith(wizard: unconfigured, decided: true));
  }

  void select(HomeTab tab) => emit(state.copyWith(tab: tab, wizard: false));
  void showWizard() => emit(state.copyWith(wizard: true));
  void dismissWizard({HomeTab? goTo}) =>
      emit(state.copyWith(wizard: false, tab: goTo));
}
