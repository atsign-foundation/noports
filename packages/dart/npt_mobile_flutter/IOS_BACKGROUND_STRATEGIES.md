# iOS Background Strategies for NoPorts Mobile

## Overview
iOS is extremely aggressive about killing background apps to save battery. This document outlines the multi-layered approach used to keep NoPorts connections alive.

## Implemented Strategies

### 1. **Background Modes (Info.plist)**
```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>           <!-- Background fetch -->
  <string>processing</string>       <!-- Background processing -->
  <string>remote-notification</string>  <!-- Push notifications -->
  <string>audio</string>            <!-- Silent audio (keeps app alive) -->
  <string>voip</string>             <!-- VoIP mode (network sockets) -->
  <string>external-accessory</string>  <!-- External device communication -->
</array>
```

**Why Each Mode:**
- `fetch` & `processing`: Allow periodic background tasks
- `remote-notification`: Keep network socket alive for push
- `audio`: Playing silent audio prevents suspension (last resort)
- `voip`: Tells iOS this is a network communication app
- `external-accessory`: For SSH tunnel hardware integration

### 2. **Wakelock (WakelockPlus)**
Prevents the device from sleeping while NoPorts is active.
```dart
await WakelockPlus.enable();
```

**Pros:** Simple, effective when app is visible
**Cons:** Only works when app is in foreground or recently backgrounded

### 3. **Foreground Service (FlutterForegroundTask)**
Displays a persistent notification showing NoPorts is active.
```dart
await FlutterForegroundTask.startService(
  serviceId: 256,
  notificationTitle: 'NoPort Active',
  notificationText: 'Network tunnel is running',
);
```

**Pros:** User visibility, iOS is less likely to kill
**Cons:** User can dismiss notification (but service continues)

### 4. **Keep-Alive Timer**
Periodic timer (every 10 seconds) that:
- Updates notification with current time
- Logs activity
- Signals to iOS that app is doing work

```dart
Timer.periodic(const Duration(seconds: 10), (timer) {
  updateStatus('Active - ${DateTime.now()}');
});
```

**Pros:** Shows continuous activity
**Cons:** Uses some battery, may not survive long backgrounds

### 5. **Lifecycle Management (AppLifecycleManager)**
Monitors app state transitions and takes action:
- **Resumed:** Check connection health after background
- **Paused:** Activate aggressive keep-alive
- **Inactive:** Prepare for background

**Benefit:** Detects when iOS has killed connections and can reconnect

## Additional Strategies to Consider

### 6. **Silent Audio Playback** (Not Yet Implemented)
Play silent audio file in a loop to prevent suspension.

```dart
// Package: just_audio or audioplayers
AudioPlayer player = AudioPlayer();
await player.setAsset('assets/silence.mp3');
await player.setLoopMode(LoopMode.one);
await player.play();
```

**Pros:** Very effective at keeping app alive
**Cons:** 
- Hacky, may violate App Store guidelines
- Uses audio session (prevents other apps from playing audio)
- Battery drain

**When to use:** Only if all other strategies fail

### 7. **Background URLSession** (Requires Native Code)
Use iOS's background URLSession for network tasks.

```swift
// iOS native code (AppDelegate.swift)
let config = URLSessionConfiguration.background(withIdentifier: "com.atsign.npt.background")
let session = URLSession(configuration: config)
```

**Pros:** iOS-native background networking
**Cons:** Complex integration, requires platform channels

### 8. **Location Updates** (Not Recommended)
Request background location updates to keep app alive.

**Pros:** Very effective
**Cons:** 
- Requires location permission
- Users will see "app is using your location"
- High battery usage
- Ethically questionable if not needed

## Testing Background Behavior

### Quick Background Test (30 seconds)
1. Start NoPorts connection
2. Press home button
3. Wait 30 seconds
4. Return to app
5. Verify connection still works

### Extended Background Test (5+ minutes)
1. Start NoPorts connection
2. Background the app
3. Use other apps heavily (games, video, etc.)
4. Wait 5-10 minutes
5. Return to NoPorts
6. Check if connection survived

### Overnight Test
1. Start connection in evening
2. Background app
3. Leave device idle overnight
4. Check connection in morning

## Monitoring Background Activity

Check Xcode console for logs:
```
iOS wakelock enabled
iOS foreground service started
iOS keep-alive timer started
iOS keep-alive heartbeat: 14:23:10
App lifecycle changed to: AppLifecycleState.paused
iOS app backgrounded - activating keep-alive strategies
```

## Battery Impact

All background strategies use battery. Monitor with:
```
Settings > Battery > NoPorts Mobile
```

**Expected impact:**
- Light usage (1-2 hours/day): 5-10% battery
- Heavy usage (8+ hours/day): 20-30% battery
- Overnight (backgrounded): 10-15% battery

## App Store Considerations

When submitting to App Store, be prepared to justify:
1. **Background modes**: "NoPorts maintains secure SSH tunnels that require continuous network connectivity"
2. **VoIP mode**: "Used for peer-to-peer network socket management"
3. **Notifications**: "Persistent notification shows active connection status to user"

**Avoid:**
- Silent audio trick (may be rejected)
- Location updates unless actually needed
- Claiming VoIP if not actually doing VoIP

## Troubleshooting

### Connection dies after 3 minutes
- iOS is enforcing background execution time limit
- Solution: Ensure all background modes are enabled in Info.plist
- Solution: Make sure foreground service is starting successfully

### Connection dies immediately when backgrounded
- Wakelock not enabled
- Solution: Check `BackgroundService.start()` is called
- Solution: Verify iOS permissions granted

### High battery drain
- Keep-alive timer too frequent
- Solution: Increase timer interval from 10s to 30s
- Solution: Only run background service when actually needed

### App Store rejection
- Silent audio being used
- Solution: Remove audio playback
- Misuse of background modes
- Solution: Only declare modes actually used

## Recommendations

1. **Always notify users** when background mode is active
2. **Provide toggle** to disable background mode (save battery)
3. **Log extensively** during testing to identify failures
4. **Test on real devices** - simulator behaves differently
5. **Test with Low Power Mode** - iOS is more aggressive
6. **Monitor crash logs** for background terminations

## Future Improvements

1. **Native iOS plugin** for better background task scheduling
2. **Dynamic strategy selection** based on battery level
3. **User-configurable aggressiveness** (battery vs reliability)
4. **Automatic reconnection** when iOS kills connection
5. **Background health checks** to verify tunnel is alive
