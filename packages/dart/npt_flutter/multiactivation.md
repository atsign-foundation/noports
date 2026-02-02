# Multi-Activation Implementation Plan

## Overview

Currently, the NPT Flutter application only supports onboarding and activating a single atsign at a time. The goal of this document is to outline the steps and tasks required to implement multi-activation support, allowing users to add and manage multiple atsigns sequentially while maintaining proper state management and data tracking.

This implementation will follow the design flow provided in the design update, allowing users to activate multiple atsigns one after the other while maintaining proper state, preferences, and associated data for each atsign.

---

## Current Architecture

### State Management

- **OnboardingCubit**: Manages single atsign information
  - `atSign`: Current atsign being worked with
  - `status`: Onboarding status (onboarded/offboarded)
  - `rootDomain`: Root domain for the atsign

### Affected Features

- **OnboardingButton**: Entry point for onboarding flow
- **OnboardingDialog/GetStartedDialog**: Atsign selection UI
- **PostOnboard**: Post-activation setup and initialization
- **ProfileListBloc**: Loads profiles for current atsign
- **FavoriteBloc**: Manages favorites for current atsign
- **SettingsBloc**: Loads settings for current atsign
- **AuthorisationService**: Initializes authorization for current atsign
- **PolicyCubit**: Loads roles for current atsign
- **TrayManager**: System tray integration with current atsign
- **AppState/AppInitialization**: App-level state management

---

## Implementation Tasks

### Phase 1: State Management Enhancement

#### Task 1.1: Extend OnboardingCubit to Support Multiple Atsigns

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/onboarding/cubit/onboarding_cubit.dart](lib/features/onboarding/cubit/onboarding_cubit.dart)

**Description**:

- Add new data structures to track multiple atsigns:
  ```
  - activatedAtsigns: List<AtsignInformation> - List of all activated atsigns
  - currentActiveAtsign: AtsignInformation - Currently active/primary atsign
  - atsignOrder: List<String> - Ordering of atsigns for UI display
  ```
- Extend `OnboardingState` to include:
  - `activatedAtsigns` - List of all onboarded atsigns with their metadata
  - `currentActiveAtsign` - The atsign currently in use
  - `atsignActivationQueue` - Queue of atsigns pending activation (for batch flows)
- Add new methods to `OnboardingCubit`:
  - `addAtsign(String atsign, String rootDomain)` - Add new atsign to activated list
  - `removeAtsign(String atsign)` - Remove atsign from activated list
  - `switchActiveAtsign(String atsign)` - Switch which atsign is currently active
  - `getActivatedAtsigns()` - Get list of all activated atsigns
  - `isAtsignActivated(String atsign)` - Check if atsign is already activated
  - `getAtsignInfo(String atsign)` - Get metadata for specific atsign

**Acceptance Criteria**:

- [ ] OnboardingState tracks multiple atsigns
- [ ] Backward compatible with existing single-atsign logic
- [ ] All new methods have unit tests
- [ ] State transitions properly tested

---

#### Task 1.2: Update OnboardingState and Model Classes

**Status**: Not Started  
**Priority**: High  
**Files to Create/Modify**:

- [lib/features/onboarding/cubit/onboarding_cubit.dart](lib/features/onboarding/cubit/onboarding_cubit.dart)
- Create: `lib/features/onboarding/models/activated_atsign_info.dart`

**Description**:

- Create `ActivatedAtsignInfo` class to store per-atsign metadata:
  - `atSign: String`
  - `rootDomain: String`
  - `status: OnboardingStatus`
  - `activationDate: DateTime`
  - `backupKeyStatus: bool` - Track backup key status per atsign
  - `preferences: Map<String, dynamic>` - Per-atsign preferences/settings
- Update `OnboardingState` equality and comparison operators to handle lists properly
- Implement serialization/deserialization for persistence

**Acceptance Criteria**:

- [ ] ActivatedAtsignInfo model created with proper equality operators
- [ ] State can be serialized/deserialized
- [ ] Comprehensive tests for model equality and data integrity

---

### Phase 2: UI/UX Flow Implementation

#### Task 2.1: Update OnboardingButton for Multi-Activation

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/onboarding/widgets/onboarding_button.dart](lib/features/onboarding/widgets/onboarding_button.dart)

**Description**:

- Add support for "Add Another Atsign" flow after successful activation
- Modify `selectAtsign()` to filter out already-activated atsigns
- Add logic to:
  - Show "Add Atsign" button in UI after first atsign activated
  - Allow users to select if they want to add another atsign
  - Queue multiple atsigns for sequential activation
- Update button states:
  - Ready: Can start new activation
  - Loading: Activation in progress
  - PostActivation: Show option to add more or complete

**Acceptance Criteria**:

- [ ] Button properly handles multiple activations in sequence
- [ ] Already-activated atsigns are filtered from selection dialogs
- [ ] Flow returns to ready state after each activation completion

---

#### Task 2.2: Create Multi-Activation Dialog Component

**Status**: Not Started  
**Priority**: High  
**Files to Create/Modify**:

- [lib/features/onboarding/widgets/multi_activation_dialog.dart](lib/features/onboarding/widgets/multi_activation_dialog.dart)
- [lib/features/onboarding/widgets/activation_status_display.dart](lib/features/onboarding/widgets/activation_status_display.dart)

**Description**:

- Create new dialog to show:
  - List of already-activated atsigns with checkmarks
  - Current atsign being activated with progress
  - Options to: "Add Another Atsign" or "Done with Activation"
- Create status display component showing:
  - Visual indicator of activation progress
  - Which atsign is currently being processed
  - Successfully activated atsigns list

**Acceptance Criteria**:

- [ ] Dialog displays current and completed activations
- [ ] User can choose to add more or complete
- [ ] Proper state management with BLoC context

---

#### Task 2.3: Update GetStartedDialog for Multi-Atsign Scenarios

**Status**: Not Started  
**Priority**: Medium  
**Files to Modify**:

- [lib/features/onboarding/widgets/get_started_dialog.dart](lib/features/onboarding/widgets/get_started_dialog.dart)

**Description**:

- Filter out already-activated atsigns from available options
- Show indicator for atsigns that are already activated
- Update help text to indicate user is adding another atsign
- Maintain selection state properly for multi-activation flow

**Acceptance Criteria**:

- [ ] Already-activated atsigns are clearly marked or filtered
- [ ] Dialog properly handles being called multiple times
- [ ] Selection state doesn't persist between activations

---

### Phase 3: Feature-Specific State Management

#### Task 3.1: Update ProfileListBloc for Multi-Atsign Support

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/profile_list/bloc/profile_list_bloc.dart](lib/features/profile_list/bloc/profile_list_bloc.dart)

**Description**:

- Extend ProfileListState to track profiles per atsign:
  - `profilesByAtsign: Map<String, List<Profile>>`
  - `currentAtsignProfiles: List<Profile>`
- Update events to include atsign context:
  - `ProfileListLoadEvent` - Include optional atsign parameter
- Modify loading logic:
  - Load profiles for specific atsign when switching
  - Cache profiles from inactive atsigns (for performance)
  - Handle loading state when switching between atsigns

- Update ProfileListLoaded state to include which atsign the profiles belong to

**Acceptance Criteria**:

- [ ] Can load profiles for different atsigns
- [ ] Switching atsigns properly updates displayed profiles
- [ ] Caching prevents unnecessary reloads
- [ ] Tests verify multi-atsign profile loading

---

#### Task 3.2: Update FavoriteBloc for Multi-Atsign Support

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/favorite/bloc/favorite_bloc.dart](lib/features/favorite/bloc/favorite_bloc.dart)

**Description**:

- Extend FavoriteState to track favorites per atsign:
  - `favoritesByAtsign: Map<String, List<Favorite>>`
  - `currentAtsignFavorites: List<Favorite>`
- Update events to include atsign context:
  - `FavoriteLoadEvent` - Include optional atsign parameter
  - `FavoriteAddEvent` - Include atsign to ensure correct association
  - `FavoriteRemoveEvent` - Include atsign context
- Modify loading logic to handle per-atsign favorites
- Ensure favorites are properly associated with their atsign

**Acceptance Criteria**:

- [ ] Favorites properly associated with correct atsign
- [ ] Switching atsigns updates displayed favorites
- [ ] Adding/removing favorites works correctly for each atsign

---

#### Task 3.3: Update SettingsBloc for Multi-Atsign Support

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/settings/bloc/settings_bloc.dart](lib/features/settings/bloc/settings_bloc.dart)

**Description**:

- Extend SettingsState to track settings per atsign:
  - `settingsByAtsign: Map<String, Settings>`
  - `currentAtsignSettings: Settings`
- Update events:
  - `SettingsLoadEvent` - Include optional atsign parameter
  - `SettingsSaveEvent` - Include atsign to ensure correct association
- Modify loading/saving logic:
  - Load settings specific to current atsign
  - Allow per-atsign settings overrides while maintaining app-level defaults
  - Properly handle first-time load for new atsigns

**Acceptance Criteria**:

- [ ] Settings properly loaded per atsign
- [ ] Switching atsigns updates application settings
- [ ] Settings changes apply only to current atsign

---

#### Task 3.4: Update AuthorisationService for Multi-Atsign Support

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/authorisation/service/authorisation_service.dart](lib/features/authorisation/service/authorisation_service.dart)

**Description**:

- Extend service to manage authorization per atsign:
  - `authorizationByAtsign: Map<String, AuthorizationData>`
  - `currentAtsignAuthorization: AuthorizationData`
- Update initialization:
  - Accept atsign parameter in `init()` method
  - Initialize authorization for specific atsign
  - Handle switching between atsigns
- Implement atsign-switching method:
  - `switchAuthorizationContext(String atsign)` - Switch authorization context

**Acceptance Criteria**:

- [ ] Authorization properly scoped per atsign
- [ ] Switching atsigns updates authorization context
- [ ] No cross-atsign authorization leakage

---

#### Task 3.5: Update PolicyCubit for Multi-Atsign Support

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/policy/cubit/policy_cubit.dart](lib/features/policy/cubit/policy_cubit.dart)

**Description**:

- Extend PolicyState to track roles/policies per atsign:
  - `policiesByAtsign: Map<String, PolicyData>`
  - `currentAtsignPolicies: PolicyData`
- Update methods:
  - `loadRoles()` - Include optional atsign parameter
  - All role/policy operations should work with current atsign context
- Handle loading state when switching atsigns

**Acceptance Criteria**:

- [ ] Policies properly loaded per atsign
- [ ] Switching atsigns updates policy data
- [ ] Policy operations scoped to current atsign

---

### Phase 4: Core Application State & Switching Logic

#### Task 4.1: Implement Atsign Switching Mechanism

**Status**: Not Started  
**Priority**: High  
**Files to Create/Modify**:

- Create: [lib/features/onboarding/util/atsign_switcher.dart](lib/features/onboarding/util/atsign_switcher.dart)
- [lib/features/onboarding/widgets/onboarding_button.dart](lib/features/onboarding/widgets/onboarding_button.dart)

**Description**:

- Create centralized `AtsignSwitcher` utility class with method:
  - `switchAtsign(BuildContext context, String newAtsign)` - Handles complete atsign switch
- This method should:
  1. Update `OnboardingCubit` with new active atsign
  2. Load ProfileListBloc data for new atsign
  3. Load FavoriteBloc data for new atsign
  4. Load SettingsBloc data for new atsign
  5. Switch AuthorisationService context
  6. Load PolicyCubit roles for new atsign
  7. Update any UI state that depends on active atsign
- Handle loading states properly so UI shows loading indicators

**Acceptance Criteria**:

- [ ] Switching atsign updates all dependent cubits/blocs
- [ ] Loading states properly managed
- [ ] No data from previous atsign leaks into new context

---

#### Task 4.2: Update PostOnboard Utility for Multi-Atsign

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/onboarding/util/post_onboard.dart](lib/features/onboarding/util/post_onboard.dart)

**Description**:

- Update `postOnboard()` to:
  - Accept atsign parameter
  - Add atsign to OnboardingCubit's activated list (don't replace)
  - Set it as active atsign
  - Initialize all data loading for this specific atsign
  - Preserve data from other already-activated atsigns
- Update flow to show option to add another atsign or complete

**Acceptance Criteria**:

- [ ] New atsign added to activated list
- [ ] All data loaded for new atsign
- [ ] Previous atsigns' data preserved
- [ ] Flow allows adding more atsigns or completing

---

#### Task 4.3: Update Backup Key Management for Multi-Atsign

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/back_up_key/cubit/backup_key_cubit.dart](lib/features/back_up_key/cubit/backup_key_cubit.dart)

**Description**:

- Extend `BackupKeyCubit` to track backup status per atsign:
  - `backupStatusByAtsign: Map<String, bool>`
  - `currentAtsignBackupStatus: bool`
- Update methods to include atsign context:
  - `setBackupKeyStatus(bool status, String? atsign)` - Set per-atsign status
- Ensure backup key settings persist per atsign

**Acceptance Criteria**:

- [ ] Backup status tracked per atsign
- [ ] Switching atsigns updates backup status display
- [ ] Backup status properly persisted

---

### Phase 5: Persistence & Data Management

#### Task 5.1: Update Local Storage for Multi-Atsign State

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- `lib/features/onboarding/util/atsign_manager.dart`
- `lib/features/profile/repository/profile_repository.dart`
- `lib/features/favorite/repository/favorite_repository.dart`
- `lib/features/settings/repository/settings_repository.dart`

**Description**:

- Update all repository classes to be multi-atsign aware:
  - Profile data stored with atsign prefix/namespace
  - Favorites stored with atsign context
  - Settings stored per atsign
  - Policies stored per atsign
- Ensure proper data isolation between atsigns
- Handle migration of existing single-atsign data

**Acceptance Criteria**:

- [ ] All data properly namespaced by atsign
- [ ] No cross-atsign data contamination
- [ ] Migration from single to multi-atsign works

---

#### Task 5.2: Update Keychain Management for Multiple Atsigns

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- Related keychain access code

**Description**:

- Ensure keychain properly stores/retrieves keys for multiple atsigns
- Verify no conflicts with multiple atsign credentials
- Ensure proper cleanup when atsign is removed

**Acceptance Criteria**:

- [ ] Multiple atsign credentials properly stored
- [ ] Correct credentials retrieved for each atsign
- [ ] No keychain conflicts

---

### Phase 6: UI Integration & Navigation

#### Task 6.1: Create Atsign Selector Component

**Status**: Not Started  
**Priority**: High  
**Files to Create**:

- [lib/features/onboarding/widgets/atsign_selector.dart](lib/features/onboarding/widgets/atsign_selector.dart)

**Description**:

- Create UI component to switch between activated atsigns
- Could be:
  - Dropdown in top navigation
  - Menu in settings
  - Quick-switch button in toolbar
- Display currently active atsign
- List all activated atsigns
- Allow quick switching between them

**Acceptance Criteria**:

- [ ] Component renders all activated atsigns
- [ ] Clicking atsign triggers switch logic
- [ ] Currently active atsign is clearly indicated
- [ ] Component integrates with existing UI

---

#### Task 6.2: Update Navigation/Routing for Multi-Atsign

**Status**: Not Started  
**Priority**: Medium  
**Files to Modify**:

- [lib/routes.dart](lib/routes.dart)

**Description**:

- Update routing to preserve atsign context
- Ensure navigation between pages doesn't lose atsign state
- Add routes for:
  - Atsign switcher UI (if in separate page)
  - Multi-activation flow

**Acceptance Criteria**:

- [ ] Navigation maintains atsign context
- [ ] Routes properly handle multi-atsign scenarios

---

#### Task 6.3: Update Home Page for Multi-Atsign Display

**Status**: Not Started  
**Priority**: Medium  
**Files to Modify**:

- Home page/wrapper widget

**Description**:

- Display which atsign is currently active
- Show atsign switcher component
- Update title/header to show active atsign

**Acceptance Criteria**:

- [ ] Active atsign displayed in UI
- [ ] Atsign switcher accessible and functional

---

### Phase 7: System Tray & Background Services

#### Task 7.1: Update TrayManager for Multi-Atsign Support

**Status**: Not Started  
**Priority**: High  
**Files to Modify**:

- [lib/features/tray_manager/cubit/tray_cubit.dart](lib/features/tray_manager/cubit/tray_cubit.dart)

**Description**:

- Update system tray menu to show:
  - Current active atsign
  - Quick access to switch atsigns
  - Profiles/favorites for current atsign
- Ensure tray menu updates when atsign is switched
- Handle menu generation for multiple atsigns

**Acceptance Criteria**:

- [ ] Tray menu shows current atsign
- [ ] Can switch atsigns from tray menu
- [ ] Menu updates correctly on atsign switch

---

### Phase 8: Testing & Quality Assurance

#### Task 8.1: Add Unit Tests for Multi-Atsign State Management

**Status**: Not Started  
**Priority**: High  
**Files to Create/Modify**:

- [test/features/onboarding/cubit/onboarding_cubit_test.dart](test/features/onboarding/cubit/onboarding_cubit_test.dart)
- Create: `test/features/onboarding/util/atsign_switcher_test.dart`

**Description**:

- Test OnboardingCubit with multiple atsigns:
  - Adding atsigns
  - Removing atsigns
  - Switching active atsign
  - State preservation
- Test AtsignSwitcher logic
- Test all bloc/cubit extensions for multi-atsign support

**Acceptance Criteria**:

- [ ] 90%+ code coverage for new/modified code
- [ ] All multi-atsign scenarios tested
- [ ] Edge cases covered (empty list, single atsign, etc.)

---

#### Task 8.2: Add Widget Tests for Multi-Activation UI

**Status**: Not Started  
**Priority**: High  
**Files to Create**:

- `test/features/onboarding/widgets/multi_activation_dialog_test.dart`
- `test/features/onboarding/widgets/atsign_selector_test.dart`

**Description**:

- Test multi-activation dialog rendering
- Test atsign selector functionality
- Test UI state updates on atsign switch
- Test error handling in UI

**Acceptance Criteria**:

- [ ] All multi-activation UI widgets tested
- [ ] User interactions properly tested
- [ ] Error states handled

---

#### Task 8.3: Add Integration Tests

**Status**: Not Started  
**Priority**: Medium  
**Files to Create**:

- `integration_test/multi_activation_e2e_test.dart`

**Description**:

- End-to-end test for complete multi-activation flow:
  1. Onboard first atsign
  2. Add second atsign
  3. Switch between atsigns
  4. Verify data loads correctly for each
  5. Remove atsign and verify cleanup

**Acceptance Criteria**:

- [ ] Complete activation flow tested end-to-end
- [ ] Data integrity verified
- [ ] Cleanup/removal tested

---

### Phase 9: Documentation & Cleanup

#### Task 9.1: Update Code Documentation

**Status**: Not Started  
**Priority**: Medium  
**Files to Modify**:

- All modified files

**Description**:

- Add comprehensive documentation to new/modified classes
- Document state management patterns
- Document how to add data structures for new features requiring multi-atsign support
- Add examples of proper atsign context usage

**Acceptance Criteria**:

- [ ] All public methods have documentation
- [ ] Complex logic explained
- [ ] Examples provided where helpful

---

#### Task 9.2: Update User Documentation

**Status**: Not Started  
**Priority**: Low  
**Files to Create/Modify**:

- README or user guide

**Description**:

- Document how users can activate multiple atsigns
- Document how to switch between atsigns
- Explain what data is per-atsign vs global

**Acceptance Criteria**:

- [ ] Clear user guide created
- [ ] Screenshots/diagrams included if helpful

---

#### Task 9.3: Code Review & Cleanup

**Status**: Not Started  
**Priority**: High

**Description**:

- Review all changes for consistency
- Remove any debug logging
- Ensure code style follows project conventions
- Optimize any performance issues
- Ensure no dead code left behind

**Acceptance Criteria**:

- [ ] All code reviewed
- [ ] Consistent style across changes
- [ ] No performance regressions
- [ ] No debug code remaining

---

## Data Tracking & State Summary

### Currently Tracked Per Atsign

- ✅ atSign (identifier)
- ✅ rootDomain (connection domain)
- ✅ onboarding status
- ✅ backup key status
- ✅ profiles
- ✅ favorites
- ✅ settings
- ✅ roles/policies
- ✅ authorization context

### New Information to Track

- 📌 List of all activated atsigns
- 📌 Activation order/sequence
- 📌 Activation date per atsign
- 📌 Atsign-specific preferences (for future)
- 📌 Currently active/primary atsign

---

## Design Flow Reference

The implementation should follow the multi-activation flow shown in the design image:

1. Initial onboarding of first atsign
2. Post-activation: Option to "Add Another Atsign" or "Done"
3. If adding: Return to atsign selection (filtered)
4. Repeat for each additional atsign
5. Final dashboard shows all activated atsigns with ability to switch

---

## Risk Assessment & Mitigation

| Risk                                          | Impact | Mitigation                                            |
| --------------------------------------------- | ------ | ----------------------------------------------------- |
| Data corruption from multi-atsign mixing      | High   | Careful testing, namespace isolation, data validation |
| State synchronization issues                  | High   | Comprehensive state management, proper event ordering |
| Performance degradation with multiple atsigns | Medium | Caching, lazy loading, efficiency testing             |
| User confusion about active atsign            | Medium | Clear UI indicators, prominent display                |
| Migration issues for existing users           | Medium | Careful migration logic, testing, rollback plan       |

---

## Dependencies & Prerequisites

- Flutter BLoC/Cubit familiarity
- Understanding of current NPT state management
- Access to existing codebase
- Test environment with multiple atsign credentials

---

## Timeline Estimate

- **Phase 1-2** (State & UI): 2-3 weeks
- **Phase 3-4** (Feature Integration): 2-3 weeks
- **Phase 5-6** (Persistence & Navigation): 1-2 weeks
- **Phase 7-8** (Tray & Testing): 1-2 weeks
- **Phase 9** (Documentation & Polish): 1 week

**Total Estimated Duration**: 7-11 weeks

---

## Success Criteria

- ✅ Multiple atsigns can be activated sequentially
- ✅ User can switch between activated atsigns
- ✅ Data properly associated with each atsign
- ✅ No data leakage between atsigns
- ✅ All existing functionality still works
- ✅ 90%+ test coverage for new/modified code
- ✅ Performance metrics maintained
- ✅ User documentation complete

---

## Next Steps

1. Review this document with team
2. Prioritize tasks based on dependencies
3. Create detailed task tickets in project management system
4. Begin Phase 1 implementation (State Management)
5. Implement test-driven development approach
6. Regular team syncs to track progress and address blockers
