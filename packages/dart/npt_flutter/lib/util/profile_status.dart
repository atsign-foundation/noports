import 'dart:io';

import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

enum ProfileStatus { off, starting, on, stopping, loading, failedToStart, failedToLoad }

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
    // Windows system tray doesn't support colored emojis, use distinct text symbols instead
    if (Platform.isWindows) {
      switch (this) {
        case ProfileStatus.off:
          return '○'; // White circle (disconnected)
        case ProfileStatus.starting:
          return '◔'; // Circle with upper right quadrant black (starting)
        case ProfileStatus.on:
          return '✓'; // Check mark (connected)
        case ProfileStatus.stopping:
          return '◑'; // Circle with left half black (stopping)
        case ProfileStatus.loading:
          return '◐'; // Circle with right half black (loading)
        case ProfileStatus.failedToStart:
          return '⚠'; // Warning sign (failed to start)
        case ProfileStatus.failedToLoad:
          return '!'; // Exclamation mark (failed to load)
      }
    }

    // macOS and Linux support colored emojis
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
