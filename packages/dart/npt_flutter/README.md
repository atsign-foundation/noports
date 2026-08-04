<a href="https://atsign.com#gh-light-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2022/05/atsign-logo-horizontal-color2022.svg#gh-light-mode-only" alt="The Atsign Foundation"></a><a href="https://atsign.com#gh-dark-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2023/08/atsign-logo-horizontal-reverse2022-Color.svg#gh-dark-mode-only" alt="The Atsign Foundation"></a>

# NoPorts Desktop

This is the source code for the NoPorts Desktop application.
See [the website](https://noports.com) for more information, or its companion
[documentation site](https://docs.noports.com) for technical and usage
information.

## Overview

NoPorts Desktop is a Flutter application that provides secure SSH connections without requiring traditional port forwarding. It uses the Atsign platform for secure, end-to-end encrypted connections.

## Features

- Secure SSH connections without port forwarding
- Profile management for multiple connections
- Favorites system for quick access
- Multi-platform support (macOS, Windows)
- Advanced connection settings
- Multiple language support

## Getting Started

### Prerequisites

- Flutter 3.0 or higher
- Dart SDK
- Platform-specific requirements:
  - **macOS:** Xcode for iOS/macOS builds
  - **Windows:** Visual Studio with C++ tools

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/atsign-foundation/noports.git
   cd sshnoports/packages/dart/npt_flutter
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

## Building From Source

Building from source is possible and will work with already activated atSigns.
However, without a valid API key, activating newly registered atSigns is not
possible. You can circumvent this by either:

- Downloading the app from the store
- Use the [at_activate binary](../sshnoports/README.md) to activate first, then
  load the generated .atkeys file into the app.

### Platform Builds

#### macOS

```bash
flutter build macos
```

#### Windows

```bash
flutter build windows
```

## Testing

### Running Tests

Run all tests:

```bash
flutter test
```

Run integration tests:

```bash
flutter test integration_test/
```

Run specific test files:

```bash
flutter test test/features/profile/
```

Run tests with coverage:

```bash
flutter test --coverage
```

### Test Structure

```
test/
├── features/
│   ├── favorite/          # Favorites functionality tests
│   ├── onboarding/        # Onboarding flow tests
│   ├── profile/           # Profile management tests
│   ├── profile_list/      # Profile listing tests
│   └── settings/          # Settings tests
├── widgets/               # Widget-specific tests
└── widget_test.dart       # Main widget tests

integration_test/
├── comprehensive_e2e_test.dart  # End-to-end workflow tests
└── README.md             # Integration test documentation
```

### Test Coverage

The project maintains comprehensive test coverage including:

- **Unit Tests:** Model and business logic testing
- **Widget Tests:** UI component testing
- **BLoC Tests:** State management testing
- **Repository Tests:** Data layer testing
- **Integration Tests:** End-to-end workflow testing

Current test metrics:

- **unit tests passing**: 100%
- **integration tests passing**: 66.6%
- **Comprehensive coverage** across all major features

## Project Structure

```
lib/
├── app.dart              # Main app configuration
├── constants.dart        # App-wide constants
├── main.dart            # Application entry point
├── routes.dart          # Route definitions
├── features/            # Feature-based organization
│   ├── favorite/        # Favorites management
│   ├── onboarding/      # User onboarding
│   ├── profile/         # SSH profile management
│   ├── profile_list/    # Profile listing and selection
│   └── settings/        # Application settings
├── localization/        # Internationalization
├── pages/              # Page-level widgets
├── styles/             # Theme and styling
├── util/               # Utility functions
└── widgets/            # Reusable widgets
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests as needed
5. Ensure all tests pass: `flutter test`
6. Submit a pull request

## Development

### Code Style

- Follow Dart/Flutter conventions
- Use meaningful variable and function names
- Add documentation for public APIs
- Maintain test coverage for new features

### State Management

The app uses BLoC pattern for state management:

- **Cubits** for simple state management
- **BLoCs** for complex state with events
- **Repositories** for data access abstraction

### Testing Guidelines

- Write tests for all new features
- Maintain existing test coverage
- Use meaningful test descriptions
- Mock external dependencies appropriately

## License

This project is licensed under the BSD 3-Clause License. See the LICENSE file for details.

## Support

- [Documentation](https://docs.noports.com)
- [Issues](https://github.com/atsign-foundation/sshnoports/issues)
- [Community Discord](https://discord.atsign.com)
