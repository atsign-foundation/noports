import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:npt_mobile_flutter/app.dart';

/// Service to keep NoPort running in the background and maintain network connections
class BackgroundService {
  static bool _isInitialized = false;
  static bool _isRunning = false;

  /// Initialize the foreground service (call once on app startup)
  static Future<void> init() async {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'noport_service',
          channelName: 'NoPort Network Service',
          channelDescription: 'Maintains network tunnel for NoPort connections',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    }

    _isInitialized = true;
    App.log('Background service initialized'.loggable);
  }

  /// Start the foreground service to keep the app alive
  static Future<bool> start() async {
    if (!_isInitialized) {
      await init();
    }

    if (_isRunning) {
      App.log('Background service already running'.loggable);
      return true;
    }

    try {
      if (Platform.isAndroid) {
        // Start foreground service
        final serviceStarted = await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'NoPort Active',
          notificationText: 'Network tunnel is running',
        );

        if (serviceStarted == null || serviceStarted == false) {
          App.log('Failed to start foreground service'.loggable);
          return false;
        }

        App.log('Android foreground service started'.loggable);
      } else if (Platform.isIOS) {
        // iOS: Enable wakelock to prevent suspension
        await WakelockPlus.enable();
        App.log('iOS wakelock enabled'.loggable);
      }

      _isRunning = true;
      return true;
    } catch (e) {
      App.log('Error starting background service: $e'.loggable);
      return false;
    }
  }

  /// Stop the foreground service
  static Future<bool> stop() async {
    if (!_isRunning) {
      return true;
    }

    try {
      if (Platform.isAndroid) {
        final serviceStopped = await FlutterForegroundTask.stopService();
        App.log('Android foreground service stopped: $serviceStopped'.loggable);
      } else if (Platform.isIOS) {
        await WakelockPlus.disable();
        App.log('iOS wakelock disabled'.loggable);
      }

      _isRunning = false;
      return true;
    } catch (e) {
      App.log('Error stopping background service: $e'.loggable);
      return false;
    }
  }

  /// Update the notification with current status
  static Future<void> updateStatus(String status) async {
    if (!_isRunning || !Platform.isAndroid) return;

    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'NoPort Active',
        notificationText: status,
      );
    } catch (e) {
      App.log('Error updating service status: $e'.loggable);
    }
  }

  /// Check if the service is currently running
  static bool get isRunning => _isRunning;
}

/// Callback function for the foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(NoPortTaskHandler());
}

/// Task handler for the foreground service
class NoPortTaskHandler extends TaskHandler {
  int _updateCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('NoPort foreground service started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _updateCount++;

    // Update notification every minute to show the service is active
    if (_updateCount % 12 == 0) {
      // Every 60 seconds (12 * 5 seconds)
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';

      FlutterForegroundTask.updateService(
        notificationText: 'Network tunnel active - Last update: $timeStr',
      );
    }

    // Send heartbeat to main isolate if needed
    FlutterForegroundTask.sendDataToMain(_updateCount);
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('NoPort foreground service destroyed at $timestamp');
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop_service') {
      print('Stop button pressed - stopping service');
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // Bring app to foreground when notification is tapped
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {
    // Handle notification dismissal if needed
  }
}
