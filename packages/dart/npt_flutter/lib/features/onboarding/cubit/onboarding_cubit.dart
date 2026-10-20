import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:npt_flutter/app.dart';

class OnboardingCubit extends LoggingCubit<OnboardingState> {
  OnboardingCubit()
    : super(
        const OnboardingState(
          status: OnboardingStatus.offboarded,
          rootDomain: 'root.atsign.org',
        ),
      );

  void setRootDomain(String rootDomain) => emit(
    OnboardingState(
      atsign: state.atsign,
      status: state.status,
      rootDomain: rootDomain,
    ),
  );
  String getRootDomain() => (state.rootDomain);

  void setAtsign(Atsign atsign) => emit(
    OnboardingState(
      atsign: atsign,
      status: state.status,
      rootDomain: state.rootDomain,
    ),
  );
  Atsign getAtsign() {
    assert(
      state.atsign != null,
      'Atsign is null. This should not happen. Please set the atsign before trying to get it.',
    );
    return state.atsign!;
  }

  void setStatus(OnboardingStatus status) => emit(
    OnboardingState(
      atsign: state.atsign,
      status: status,
      rootDomain: state.rootDomain,
    ),
  );
  OnboardingStatus getStatus() => (state.status);

  /// If state is passed, all other arguments are ignored
  /// If individual arguments (atsign, rootDomain, status) are passed
  /// then they will override the value of the current state
  /// keeping unspecified values the same
  void setState({
    Atsign? atsign,
    OnboardingStatus? status,
    String? rootDomain,
  }) => emit(
    OnboardingState(
      atsign: atsign ?? state.atsign,
      status: status ?? state.status,
      rootDomain: rootDomain ?? state.rootDomain,
    ),
  );
}

enum OnboardingStatus { onboarded, offboarded }

class OnboardingState extends Loggable {
  final OnboardingStatus status;
  final Atsign? atsign;
  final String rootDomain;
  const OnboardingState({
    required this.status,
    this.atsign,
    required this.rootDomain,
  });

  @override
  List<Object?> get props => [atsign, status, rootDomain];

  @override
  String toString() {
    return 'OnboardingState($atsign, ${status.name}, $rootDomain)';
  }
}
