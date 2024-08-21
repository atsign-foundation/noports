import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/logging/logging.dart';

part 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(const OnboardingInitial());

  void onboard(String atSign) => emit(Onboarded(atSign));
  void offboard() => emit(const OnboardingInitial());
}
