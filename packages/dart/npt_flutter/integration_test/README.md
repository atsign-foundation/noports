# NPT Flutter Integration Testing

This directory contains integration tests for the NPT Flutter application, focusing on end-to-end user workflows and critical app functionality.

## Test Files

### `comprehensive_e2e_test.dart`

A complete end-to-end test suite covering the full user journey:

- **Complete App Workflow**: Tests the entire flow from app launch through onboarding, dashboard usage, profile management, and settings configuration
- **Workflow Interruption Recovery**: Validates app resilience when user workflows are interrupted
- **Error Resilience & Stress Testing**: Ensures app stability under various stress conditions

**Key Test Scenarios:**

- App launch and initialization verification
- Complete onboarding process with dialog interactions
- Dashboard navigation and profile list functionality
- Profile creation, editing, and management operations
- Settings page interactions and configuration changes
- Error handling and recovery mechanisms
- UI responsiveness under rapid user interactions

## Running the Tests

### Prerequisites

- Flutter SDK installed and configured
- macOS environment (primary target platform)
- NPT Flutter app dependencies installed (`flutter pub get`)

### Running Integration Tests

```bash
# Run comprehensive end-to-end tests
flutter test integration_test/comprehensive_e2e_test.dart

# Run all integration tests
flutter test integration_test/
```

## Test Coverage

The integration test focuses on critical user flows and app functionality:

### Core User Workflows

- [x] App initialization and startup sequence
- [x] Complete onboarding process with dialog interactions
- [x] Dashboard navigation and profile access
- [x] Profile management operations (create, edit, delete)
- [x] Settings configuration and persistence
- [x] Navigation between major app sections

### Critical UI Interactions

- [x] Button interactions and state management
- [x] Form field validation and data entry
- [x] Dialog and modal interactions
- [x] Loading states and progress indicators
- [x] Error states and recovery flows

### Stability & Performance

- [x] Rapid user interaction handling
- [x] Navigation interruption recovery
- [x] Memory and state management
- [x] Exception handling and graceful degradation

## Test Structure and Philosophy

The integration test follows this pattern:

1. **Setup**: Launch app and verify initial state
2. **Execute**: Perform realistic user interactions across all major features
3. **Verify**: Confirm expected outcomes and state changes
4. **Cleanup**: Ensure proper test isolation

## Contributing

When adding new integration tests:

1. Focus on user-facing workflows rather than implementation details
2. Use realistic test data and scenarios
3. Include comprehensive logging for debugging
4. Ensure tests are deterministic and repeatable
5. Update this documentation with new test coverage

## Notes

- Integration tests are designed to run on macOS as the primary target platform
- Tests use self-contained scenarios with no external dependencies
- Test execution includes automatic cleanup to prevent state pollution
