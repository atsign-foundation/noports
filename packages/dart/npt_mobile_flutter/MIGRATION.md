# Migration from Desktop to Mobile

This document describes the key differences and adaptations made when porting npt_flutter (Desktop) to npt_mobile_flutter (Mobile).

## Removed Features

### Desktop-Specific Components

1. **System Tray Manager**
   - Removed `tray_manager` package dependency
   - Removed `/lib/features/tray_manager/` feature module
   - Removed tray icon and menu functionality

2. **Window Management**
   - Removed `window_manager` package dependency
   - Removed window sizing and positioning controls
   - Removed from `main.dart` initialization

## Modified Files

### Core Files

1. **pubspec.yaml**
   - Removed: `window_manager`, `tray_manager`, `msix`
   - Updated: `at_onboarding_flutter` to use pub.dev version instead of git
   - Added: `dependency_overrides` for `file` package compatibility

2. **main.dart**
   - Removed window manager initialization
   - Simplified to mobile-only startup

3. **app.dart**
   - Removed `TrayManager` widget wrapper
   - Kept all BLoC providers and repository providers
   - Maintained same architecture

### Import Changes

All imports were automatically updated from:
```dart
import 'package:npt_flutter/...';
```

To:
```dart
import 'package:npt_mobile_flutter/...';
```

## Platform Configuration

### Android

Files created/modified:
- `android/app/src/main/AndroidManifest.xml`
  - App name: "NoPorts Mobile"
  - Added internet and network state permissions
- `android/app/build.gradle.kts`
- `android/settings.gradle.kts`

### iOS

Files created/modified:
- `ios/Runner/Info.plist`
  - App name: "NoPorts Mobile"
  - Display name: "NoPorts Mobile"
- `ios/Runner.xcodeproj/`
- iOS workspace and scheme files

## Preserved Architecture

The following architecture components remain identical:

### State Management
- BLoC pattern with `flutter_bloc`
- LoggingBloc and LoggingCubit base classes
- All feature-specific cubits and blocs

### Features (All Preserved)
- **Onboarding**: atSign activation and authentication
- **Profile Management**: Connection profile CRUD
- **Profile List**: Display and manage profiles
- **Settings**: App configuration
- **Authorization**: Device authorization management  
- **Policy Management**: Role-based access control
- **Policy Form**: Policy creation and editing
- **Policy Logs**: Policy audit logging
- **Favorites**: Quick access to profiles
- **Logging**: Application logging system
- **Backup Key**: atKey backup functionality

### Repositories (All Preserved)
- ProfileRepository
- SettingsRepository
- FavoriteRepository
- BackUpKeyRepository
- RoleRepository
- AuthorisationService
- ContactsService

### Widgets & Pages (All Preserved)
All UI components were copied and will work with mobile layouts:
- Connection page
- Settings page
- Profile form page
- Authorization page
- Policy page
- Onboarding page
- Loading page

## Future Mobile-Specific Enhancements

Consider adding these mobile-specific features:

1. **Push Notifications**: For connection status updates
2. **Biometric Authentication**: Fingerprint/Face ID for quick access
3. **Share Extensions**: Share profiles between devices
4. **Mobile-Optimized UI**: Adapt layouts for various screen sizes
5. **Gesture Controls**: Swipe actions for profile management
6. **Offline Mode**: Better handling of network interruptions
7. **Background Connections**: Keep connections alive in background

## Testing Recommendations

### Unit Tests
All existing unit tests should work with minimal changes.

### Widget Tests
May need adjustment for mobile-specific interactions.

### Integration Tests
- Test on both iOS and Android
- Test various screen sizes (phone and tablet)
- Test orientation changes
- Test background/foreground transitions

## Build & Deployment

### Development
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

### Production
```bash
# iOS
flutter build ipa --release

# Android
flutter build appbundle --release
```

## Known Issues & Considerations

1. **Plugin Warnings**: Some atSign packages show warnings for Linux/Windows/macOS - these are expected and don't affect iOS/Android builds.

2. **Dependency Overrides**: The `file` package requires an override to resolve conflicts between `device_info_plus` and `noports_core`.

3. **Asset Management**: Ensure all assets from desktop version are mobile-friendly (size, resolution).

4. **API Keys**: Configure `.env` file with appropriate API keys for mobile apps.

## Maintenance

When updating from npt_flutter:

1. Check for new features in desktop version
2. Evaluate if features are applicable to mobile
3. Port applicable changes
4. Skip desktop-specific features (tray, window management)
5. Test on both platforms
6. Update this migration guide
