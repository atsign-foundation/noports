import 'package:npt_flutter/features/logging/models/logging_bloc.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';

class OnboardingCubit extends LoggingCubit<OnboardingState> {
  OnboardingCubit()
      : super(const OnboardingState(atSign: '', status: OnboardingStatus.offboarded, rootDomain: 'root.atsign.org'));

  void setRootDomain(String rootDomain) =>
      emit(OnboardingState(atSign: state.atSign, status: state.status, rootDomain: rootDomain));
  String getRootDomain() => (state.rootDomain);

  void setAtSign(String atSign) =>
      emit(OnboardingState(atSign: atSign, status: state.status, rootDomain: state.rootDomain));
  String getAtSign() => (state.atSign);

  void setStatus(OnboardingStatus status) =>
      emit(OnboardingState(atSign: state.atSign, status: status, rootDomain: state.rootDomain));
  OnboardingStatus getStatus() => (state.status);

  /// If state is passed, all other arguments are ignored
  /// If individual arguments (atsign, rootDomain, status) are passed
  /// then they will override the value of the current state
  /// keeping unspecified values the same
  void setState({
    String? atSign,
    OnboardingStatus? status,
    String? rootDomain,
  }) =>
      emit(OnboardingState(
        atSign: atSign ?? this.state.atSign,
        status: status ?? this.state.status,
        rootDomain: rootDomain ?? this.state.rootDomain,
      ));
}

enum OnboardingStatus { onboarded, offboarded }

class OnboardingState extends AtsignInformation {
  final OnboardingStatus status;
  const OnboardingState({required this.status, required super.atSign, required super.rootDomain});

  @override
  List<Object?> get props => [atSign, status, rootDomain];

  @override
  String toString() {
    return 'OnboardingState($atSign, ${status.name}, $rootDomain)';
  }
}
