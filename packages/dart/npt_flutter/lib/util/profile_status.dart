import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';

enum ProfileStatus {
  off,
  starting,
  on,
  stopping,
  loading,
  failedToStart,
  failedToLoad,
}

extension ProfileStatusExtension on ProfileStatus {
  String get message {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    switch (this) {
      case ProfileStatus.off:
        return strings.profileStatusLoaded;
      case ProfileStatus.starting:
        return strings.profileStatusStarting;
      case ProfileStatus.on:
        return strings.profileStatusStarted;
      case ProfileStatus.stopping:
        return strings.profileStatusStopping;
      case ProfileStatus.loading:
        return strings.profileStatusLoading;
      case ProfileStatus.failedToStart:
        return strings.profileStatusFailedStart;
      case ProfileStatus.failedToLoad:
        return strings.profileStatusFailedLoad;
    }
  }

  String get emoji {
    switch (this) {
      case ProfileStatus.off:
        return '⚪';
      case ProfileStatus.starting:
        return '🟡';
      case ProfileStatus.on:
        return '🟢';
      case ProfileStatus.stopping:
        return '🟡';
      case ProfileStatus.loading:
        return '🟡';
      case ProfileStatus.failedToStart:
        return '🔴';
      case ProfileStatus.failedToLoad:
        return '🔴';
    }
  }
}
