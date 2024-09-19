part of 'onboarding_cubit.dart';

sealed class OnboardingState extends Loggable {
  const OnboardingState();

  @override
  List<Object> get props => [];
}

final class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();

  @override
  String toString() {
    return 'OnboardingInitial';
  }
}

final class Onboarded extends OnboardingState {
  final String atSign;
  const Onboarded(this.atSign);

  @override
  List<Object> get props => [atSign];

  @override
  String toString() {
    return 'Onboarded($atSign)';
  }
}
