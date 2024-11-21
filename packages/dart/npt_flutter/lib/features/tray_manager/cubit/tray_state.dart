part of 'tray_cubit.dart';

sealed class TrayState extends Loggable {
  const TrayState();
  @override
  List<Object?> get props => [];
}

final class TrayInitial extends TrayState {
  const TrayInitial();

  @override
  String toString() {
    return 'TrayInitial';
  }
}

final class TrayLoaded extends TrayState {
  const TrayLoaded();

  @override
  List<Object?> get props => [];

  @override
  String toString() {
    return 'TrayLoaded';
  }
}
