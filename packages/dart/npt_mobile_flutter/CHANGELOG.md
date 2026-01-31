# Changelog

All notable changes to the NoPorts Mobile project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-30

### Added
- Initial release of NoPorts Mobile for iOS and Android
- Ported from NoPorts Desktop (npt_flutter) with mobile-specific adaptations
- Profile management for SSH connections
- Favorites system for quick access
- Multi-language support (English, Spanish, Portuguese, Chinese)
- atSign onboarding and authentication
- Policy-based access control
- Device authorization management
- Mobile-optimized UI for iOS and Android

### Changed
- Removed desktop-specific features (system tray, window management)
- Adapted UI for mobile screens and touch interactions
- Updated dependencies for mobile compatibility

### Architecture
- BLoC pattern for state management
- Repository pattern for data persistence
- Feature-based project structure
- Shared noports_core for SSH connection logic
