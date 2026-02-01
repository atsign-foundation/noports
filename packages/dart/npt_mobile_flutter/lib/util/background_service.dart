import 'dart:io';
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:npt_mobile_flutter/app.dart';

/// Service to keep NoPort running in the background and maintain network connections
class BackgroundService {
  static bool _isInitialized = false;
  static bool _isRunning = false;
  static Timer? _iosKeepAliveTimer;

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
          showNotification: true,  // Changed to true for better iOS visibility
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
    } else if (Platform.isIOS) {
      // iOS-specific initialization
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'noport_service',
          channelName: 'NoPort Network Service',
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(2000), // More frequent on iOS
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
        // iOS: Multi-layered approach to stay alive
        
        // 1. Enable wakelock
        await WakelockPlus.enable();
        App.log('iOS wakelock enabled'.loggable);
        
        // 2. Start foreground task with notification
        final serviceStarted = await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'NoPort Active',
          notificationText: 'Network tunnel is running',
        );
        
        if (serviceStarted == true) {
          App.log('iOS foreground service started'.loggable);
        }
        
        // 3. Start periodic keep-alive timer to prevent suspension
        _startIOSKeepAlive();
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
        // Stop all iOS keep-alive mechanisms
        _iosKeepAliveTimer?.cancel();
        _iosKeepAliveTimer = null;
        
        await FlutterForegroundTask.stopService();
        await WakelockPlus.disable();
        App.log('iOS background services stopped'.loggable);
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
  
  /// iOS-specific: Start periodic keep-alive timer
  /// This sends regular signals to prevent iOS from suspending the app
  static void _startIOSKeepAlive() {
    if (!Platform.isIOS) return;
    
    _iosKeepAliveTimer?.cancel();
    
    // Send a keep-alive signal every 10 seconds
    _iosKeepAliveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      // Update notification to show app is alive
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
                     '${now.minute.toString().padLeft(2, '0')}:'
                     '${now.second.toString().padLeft(2, '0')}';
      
      updateStatus('Active - $timeStr');
      
      // Log to show activity
      if (now.second % 30 == 0) { // Log every 30 seconds
        App.log('iOS keep-alive heartbeat: $timeStr'.loggable);
      }
    });
    
    App.log('iOS keep-alive timer started'.loggable);
  }
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
