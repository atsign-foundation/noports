<a href="https://atsign.com#gh-light-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2022/05/atsign-logo-horizontal-color2022.svg#gh-light-mode-only" alt="The Atsign Foundation"></a><a href="https://atsign.com#gh-dark-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2023/08/atsign-logo-horizontal-reverse2022-Color.svg#gh-dark-mode-only" alt="The Atsign Foundation"></a>

# NoPorts Desktop

This is the source code for the NoPorts Desktop application.
See [the website](https://noports.com) for more information, or its companion
[documentation site](https://docs.noports.com) for technical and usage
information.

## Getting Started

### Prerequisites

- Flutter 3.0 or higher
- Dart SDK
- Platform-specific requirements:
  - **macOS:** Xcode for iOS/macOS builds
  - **Windows:** Visual Studio with C++ tools

### Run from Source

1. Clone the repository:

   ```bash
   git clone https://github.com/atsign-foundation/sshnoports.git
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
  load the generated .atKeys file into the app.

### Commands to build

```sh
flutter pub get
dart run build_runner build
flutter build <OS> --release --dart-define-from-file .env.json
```

Example .env.json file for production NoPorts Desktop:

```json
{
  "roots": {
    "root.atsign.org": {
      "port": 64,
      "description": {
        "en": "Atsign (default)"
      },
      "registrar-url": "my.atsign.com",
      "api-key": "REDACTED"
    },
    "vip.ve.atsign.zone": {
      "description": {
        "en": "Demo Environment (VE)"
      }
    }
  }
}
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
