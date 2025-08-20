# NPT Flutter Testing Strategy

This document outlines the testing approach for the NPT Flutter application, prioritizing critical functionality and maintainability.

## **Testing Pyramid & Priority Order**

### **1. Unit Tests (Highest Priority)**

#### **Core Models & Data Structures**
- ✅ **Profile model** - JSON serialization, copyWith, Favoritable mixin
- ✅ **Settings model** - Default settings, JSON handling, preferences  
- ✅ **Favorite models** - Profile relationships, JSON serialization

#### **Repositories (Data Layer)**
- ✅ **ProfileRepository** - CRUD operations, AtKey handling, caching
- ✅ **SettingsRepository** - Settings persistence, AtClient integration
- ✅ **FavoriteRepository** - Favorite management, cache invalidation

#### **BLoC/Cubit Business Logic**
- ✅ **ProfileBloc** - Profile loading, creation, editing events
- ✅ **ProfileListBloc** - List management, deletion, favorite integration
- ✅ **SettingsBloc** - Settings loading and persistence
- ✅ **FavoriteBloc** - Add/remove favorites, profile relationships
- ✅ **OnboardingCubit** - State management during onboarding
- ✅ **ProfilesRunningCubit** - Socket connection management
- ✅ **ProfilesSelectedCubit** - Multi-selection state

### **2. Widget Tests (Medium Priority)**
- ✅ **ProfileView** - Profile display and form interactions
- ✅ **ProfileListView** - List rendering, selection, actions
- ✅ **SettingsView** - Settings form and persistence

### **3. Integration Tests (High Value)**
- ✅ **comprehensive_e2e_test.dart** - Complete user workflows from onboarding to profile management

## **Current Test Coverage**

### ✅ **Completed Tests**
- All core models with comprehensive test coverage
- Repository layer with mocking and error handling
- Business logic (BLoC/Cubit) with state transitions
- Key widget tests for main user interfaces
- End-to-end integration test covering full user journey

### **Test Quality Standards**
- **Unit Tests**: 90%+ code coverage for models and repositories
- **BLoC Tests**: All state transitions and edge cases covered
- **Widget Tests**: Critical user interactions and error states
- **Integration Tests**: Complete user workflows with realistic scenarios

## **Testing Philosophy**

1. **Test Behavior, Not Implementation** - Focus on what the code does, not how
2. **Realistic Test Data** - Use meaningful test data that reflects real usage
3. **Deterministic Tests** - Ensure tests are repeatable and reliable
4. **Fast Feedback** - Unit tests should run quickly for rapid development
5. **Comprehensive Integration** - E2E tests cover critical user paths

## **Running Tests**

```bash
# Run all unit tests
flutter test test/

# Run integration tests  
flutter test integration_test/

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/features/profile/models/profile_test.dart
```

## **Maintenance Guidelines**

- **Add tests for new features** before implementation
- **Update tests** when refactoring existing code  
- **Remove obsolete tests** when features are deprecated
- **Keep test data realistic** and representative of actual usage
- **Mock external dependencies** appropriately in unit tests

  - CRUD operations for profiles
  - AtKey handling and namespacing
  - Caching mechanisms
  - Error handling

- **SettingsRepository** (settings_repository.dart)

  - Settings persistence and retrieval
  - Default settings fallback
  - AtClient integration

- **FavoriteRepository** (favorite_repository.dart)
  - Favorite management operations
  - Profile ID tracking
  - Cache invalidation

### **2. BLoC/Cubit Tests (High Priority)**

#### **Core Business Logic**

- **ProfileBloc** (profile_bloc.dart)

  - Profile loading, editing, saving
  - Start/stop profile operations
  - State transitions (Initial → Loading → Loaded/Failed)
  - Error handling during NPT operations

- **ProfileListBloc** (profile_list_bloc.dart)

  - Profile list management
  - Add/delete operations
  - Favorite integration
  - Bulk operations

- **SettingsBloc** (settings_bloc.dart)

  - Settings loading and saving
  - Default settings fallback
  - Language/layout preferences

- **FavoriteBloc** (favorite_bloc.dart)
  - Add/remove favorites
  - Favorite state management
  - Profile relationship tracking

#### **UI State Management**

- **OnboardingCubit** (onboarding_cubit.dart)

  - AtSign state management
  - Onboarding flow control

- **ProfilesSelectedCubit** & **ProfilesRunningCubit**
  - UI selection state
  - Running profile tracking

### **3. Widget Tests (Medium Priority)**

#### **Core Views**

- **ProfileView** (profile_view.dart)

  - Different layout rendering (minimal vs SSH style)
  - State-based UI updates
  - Button interactions

- **ProfileListView** (profile_list_view.dart)

  - Profile list rendering
  - Empty state handling
  - Loading states

- **SettingsView** (settings_view.dart)
  - Settings form rendering
  - Language switching
  - Layout preferences

#### **Custom Widgets**

- **ProfileFavoriteButton** (profile_favorite_button.dart)
- **Profile form widgets** (widgets)
- **Settings widgets** (widgets)

### **4. Integration Tests (Medium Priority)**

#### **Critical User Flows**

- **Onboarding Flow**

  - AtSign setup and authentication
  - Post-onboarding data loading

- **Profile Management**

  - Create → Save → Start → Stop profile lifecycle
  - Import/Export functionality
  - Favorite operations

- **Settings Management**
  - Settings persistence across app restarts
  - Language changes affecting UI

### **5. Utility & Helper Tests (Lower Priority)**

#### **Utilities**

- **Export/Import functionality** (export.dart)
- **Language utilities** (language.dart)
- **UUID handling** (uuid.dart)

#### **Navigation & Routing**

- **Routes** (routes.dart)
- **Navigation state management**

## **Testing Implementation Order**

### **Phase 1: Foundation (Week 1-2)**

1. Profile model tests
2. Settings model tests
3. Basic repository tests (ProfileRepository, SettingsRepository)

### **Phase 2: Business Logic (Week 3-4)**

1. ProfileBloc comprehensive tests
2. ProfileListBloc tests
3. SettingsBloc tests
4. FavoriteBloc tests

### **Phase 3: UI Components (Week 5-6)**

1. Core view tests (ProfileView, ProfileListView)
2. Form widget tests
3. Settings widget tests

### **Phase 4: Integration & Edge Cases (Week 7-8)**

1. End-to-end user flows
2. Error scenarios and edge cases
3. Performance testing with large datasets

## **Key Testing Considerations**

1. **AtClient Mocking**: Most tests will need to mock AtClient interactions
2. **BLoC Testing**: Use bloc_test package for comprehensive state testing
3. **Navigation Testing**: Mock Navigator and test route transitions
4. **File Operations**: Mock file picker and export/import operations
5. **System Tray**: Mock tray manager for desktop-specific features

This testing strategy prioritizes the core business logic and data integrity first, then builds up to UI and integration testing. The modular structure of your codebase with clear separation of concerns makes it well-suited for comprehensive testing.
