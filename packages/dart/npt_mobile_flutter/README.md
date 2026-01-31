<a href="https://atsign.com#gh-light-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2022/05/atsign-logo-horizontal-color2022.svg#gh-light-mode-only" alt="The Atsign Foundation"></a><a href="https://atsign.com#gh-dark-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2023/08/atsign-logo-horizontal-reverse2022-Color.svg#gh-dark-mode-only" alt="The Atsign Foundation"></a>

# NoPorts Mobile

This is the source code for the NoPorts Mobile application for iOS and Android.
See [the website](https://noports.com) for more information, or its companion
[documentation site](https://docs.noports.com) for technical and usage information.

## Overview

NoPorts Mobile is a Flutter application that provides secure remote access connections without requiring traditional port forwarding. It uses the atProtocol for secure, end-to-end encrypted connections on mobile devices.

This project is a mobile port of the NoPorts Desktop application (npt_flutter), adapted specifically for iOS and Android platforms.

## Features

- Secure remote access connections without port forwarding
- Profile management for multiple connections
- Favorites system for quick access
- Mobile-optimized UI for iOS and Android
- Advanced connection settings
- Multiple language support (English, Spanish, Portuguese, Chinese)
- APKAM (atProtocol Key Access Management) support
- Policy-based access control

## Architecture

NoPorts Mobile uses the same architecture as NoPorts Desktop:

- **BLoC Pattern**: State management using flutter_bloc
- **Repository Pattern**: Data persistence and business logic separation
- **Feature-based Structure**: Organized by features (profile, settings, onboarding, etc.)
- **Dependency Injection**: Using flutter_bloc's repository providers

### Key Components

- **noports_core**: Shared core library for SSH connection logic
- **Features**:
  - **Onboarding**: atSign activation and authentication
  - **Profile Management**: Create and manage connection profiles
  - **Settings**: App configuration and preferences
  - **Authorization**: Manage device authorizations
  - **Policy Management**: Define and enforce access policies
  - **Favorites**: Quick access to frequently used profiles

## Getting Started

### Prerequisites

- Flutter 3.8 or higher
- Dart SDK 3.8 or higher
- Platform-specific requirements:
  - **iOS**: Xcode 14 or higher, macOS for development
  - **Android**: Android Studio or Android SDK tools

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/atsign-foundation/noports.git
   cd sshnoports/packages/dart/npt_mobile_flutter
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Set up environment variables:
   - Copy `.env.template` to `.env` (if available)
   - Or create a `.env` file with required configuration

4. Run the application:

   ```bash
   # For iOS
   flutter run -d ios

   # For Android
   flutter run -d android
   ```

## Building From Source

### iOS Build

```bash
# Development build
flutter build ios --debug

# Release build
flutter build ios --release

# Create IPA for distribution
flutter build ipa --release
```

### Android Build

```bash
# Development build
flutter build apk --debug

# Release build
flutter build apk --release

# App Bundle for Play Store
flutter build appbundle --release
```

## Configuration

### Android Permissions

The app requires the following permissions (configured in AndroidManifest.xml):
- `INTERNET`: For network connections
- `ACCESS_NETWORK_STATE`: To check connectivity

### iOS Permissions

Required entries in Info.plist:
- Network usage description
- Background modes (if needed for persistent connections)

## Differences from Desktop Version

The mobile version has the following adaptations from the desktop version:

1. **No System Tray**: Removed tray_manager functionality
2. **No Window Management**: Removed window_manager controls
3. **Mobile-optimized UI**: Adapted layouts for smaller screens
4. **Touch-friendly Controls**: Larger tap targets and mobile gestures
5. **Platform-specific Features**: iOS and Android native integrations

## Testing

Run tests:

```bash
flutter test
```

Run integration tests:

```bash
flutter test integration_test/
```

## Dependencies

Key dependencies include:
- `at_client_mobile`: atProtocol client for mobile
- `at_onboarding_flutter`: atSign onboarding flow
- `flutter_bloc`: State management
- `noports_core`: Core SSH connection logic
- `socket_connector`: Socket connection management

For the complete list, see [pubspec.yaml](pubspec.yaml).

## Troubleshooting

### Common Issues

1. **Build failures**: Ensure all dependencies are up to date with `flutter pub get`
2. **iOS code signing**: Configure your development team in Xcode
3. **Android SDK issues**: Verify Android SDK path and tools are installed

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](../../../CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the BSD 3-Clause License. See [LICENSE](../../../LICENSE) for details.

## Support

- Documentation: https://docs.noports.com
- Issues: https://github.com/atsign-foundation/noports/issues
- Discord: https://discord.atsign.com

## Acknowledgments

This mobile application is based on the NoPorts Desktop application and shares the same core architecture and functionality.
