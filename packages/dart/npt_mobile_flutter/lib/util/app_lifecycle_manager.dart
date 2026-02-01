import 'dart:io';
import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'background_service.dart';

/// Manages app lifecycle events to maintain background connectivity on iOS
class AppLifecycleManager extends WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  bool _isInitialized = false;
  DateTime? _backgroundTime;

  /// Initialize lifecycle observer
  void init() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    App.log('AppLifecycleManager initialized'.loggable);
  }

  /// Clean up
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    App.log('App lifecycle changed to: $state'.loggable);

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }

  void _onAppResumed() {
    App.log('App resumed to foreground'.loggable);
    
    if (_backgroundTime != null) {
      final duration = DateTime.now().difference(_backgroundTime!);
      App.log('App was in background for ${duration.inSeconds} seconds'.loggable);
      
      // If iOS killed connections while in background, we might need to reconnect
      if (Platform.isIOS && duration.inSeconds > 30) {
        App.log('Long background duration on iOS - checking connections'.loggable);
        // TODO: Trigger connection health check
      }
      
      _backgroundTime = null;
    }
    
    // Ensure background service is still running
    if (BackgroundService.isRunning) {
      BackgroundService.updateStatus('Active - Foreground');
    }
  }

  void _onAppInactive() {
    App.log('App became inactive'.loggable);
    // App is transitioning - don't take action yet
  }

  void _onAppPaused() {
    _backgroundTime = DateTime.now();
    App.log('App paused (moved to background)'.loggable);
    
    // iOS: Aggressively try to stay alive
    if (Platform.isIOS && BackgroundService.isRunning) {
      App.log('iOS app backgrounded - activating keep-alive strategies'.loggable);
      BackgroundService.updateStatus('Active - Background');
      
      // Schedule immediate background task to show we're still working
      _scheduleIOSBackgroundWork();
    }
  }

  void _onAppDetached() {
    App.log('App detached'.loggable);
  }

  void _onAppHidden() {
    App.log('App hidden'.loggable);
  }

  /// iOS-specific: Schedule background work to keep app alive
  void _scheduleIOSBackgroundWork() {
    if (!Platform.isIOS) return;
    
    // This is a placeholder - actual implementation would use
    // BGTaskScheduler or similar iOS-specific APIs via platform channels
    App.log('Scheduling iOS background tasks'.loggable);
    
    // The combination of:
    // 1. Foreground notification (from FlutterForegroundTask)
    // 2. Wakelock (from WakelockPlus)
    // 3. Periodic timer (from BackgroundService)
    // 4. Background modes in Info.plist (audio, voip, etc.)
    // Should help keep the app alive
  }
}
