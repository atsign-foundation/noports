import 'package:npt_mobile_flutter/features/logging/models/loggable.dart';

enum LightState {
  green, // connected
  red, // disconnected
  clear, // unsure
}

sealed class PolicyStatusLightState extends Loggable {
  const PolicyStatusLightState();

  @override
  List<Object?> get props => [];

  @override
  String toString() => 'PolicyStatusLightState()';
}

final class PolicyStatusLightInitial extends PolicyStatusLightState {
  const PolicyStatusLightInitial();

  @override
  List<Object?> get props => [];

  @override
  String toString() => 'PolicyStatusLightInitial()';
}

final class PolicyStatusLightLoading extends PolicyStatusLightState {
  final LightState lightState = LightState.clear;

  const PolicyStatusLightLoading();

  @override
  List<Object?> get props => [lightState];

  @override
  String toString() => 'PolicyStatusLightLoading()';
}

final class PolicyStatusLightLoaded extends PolicyStatusLightState {
  final LightState lightState;
  final String? message;

  const PolicyStatusLightLoaded({
    this.lightState = LightState.red,
    this.message,
  });

  @override
  List<Object?> get props => [lightState, message];

  @override
  String toString() {
    return 'PolicyStatusLightState;(lightState=$lightState, message=$message)';
  }
}
