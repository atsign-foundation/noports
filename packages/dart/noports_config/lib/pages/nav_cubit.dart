import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum HomeTab { status, configuration, keys, diagnostics }

class NavState extends Equatable {
  const NavState({this.tab = HomeTab.status, this.wizard = false, this.wizardDismissed = false});
  final HomeTab tab;

  /// Show the first-run wizard instead of the tabs.
  final bool wizard;

  /// The user skipped the wizard this session; do not pop it up again.
  final bool wizardDismissed;

  NavState copyWith({HomeTab? tab, bool? wizard, bool? wizardDismissed}) => NavState(
    tab: tab ?? this.tab,
    wizard: wizard ?? this.wizard,
    wizardDismissed: wizardDismissed ?? this.wizardDismissed,
  );

  @override
  List<Object?> get props => [tab, wizard, wizardDismissed];
}

class NavCubit extends Cubit<NavState> {
  NavCubit() : super(const NavState());

  void select(HomeTab tab) => emit(state.copyWith(tab: tab, wizard: false));
  void showWizard() => emit(state.copyWith(wizard: true));
  void dismissWizard({HomeTab? goTo}) =>
      emit(state.copyWith(wizard: false, wizardDismissed: true, tab: goTo));
}
