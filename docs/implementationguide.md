# Implementation Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Development Environment Setup](#development-environment-setup)
3. [Sprint-by-Sprint Instructions](#sprint-by-sprint-instructions)
4. [Testing Strategy](#testing-strategy)
5. [Deployment Steps](#deployment-steps)
6. [Maintenance & Ongoing Tasks](#maintenance--ongoing-tasks)

---

## Prerequisites

- **Basic Swift / SwiftUI Knowledge**: Familiarity with MVVM or a similar design pattern is assumed.
- **OAuth2 Understanding**: Know how tokens are requested, refreshed, and stored securely.
- **RESTful APIs**: Know how to consume JSON endpoints, parse responses, and handle errors.

---

## Development Environment Setup

1. **Xcode**: Install the latest stable release (e.g., Xcode 14+).
2. **Swift Toolchain**: Minimum Swift 5.5+ to leverage async/await if desired.
3. **CocoaPods or Swift Package Manager** for any third-party libraries:
   - Examples:
     - `Alamofire` (networking) or use native `URLSession`.
     - `OAuthSwift` or a custom approach for OAuth2.
4. **Git**: For version control. Create a repo on GitHub or GitLab.
5. **iOS Devices / Simulators**: iOS 15+ recommended to ensure modern SwiftUI features.

---

## Sprint-by-Sprint Instructions

### Sprint 0: Project Scaffolding & Basic Architecture

**Goal**: Lay the foundation of the project, ensuring a clear folder structure and minimal placeholders for future code.

1. **Create the Xcode Project**  
   - Use the **App** template if using SwiftUI.  
   - Name it something like `SmartHomePlatform`.

2. **Set up Folder Structure**:
   - `Sources/` (or `SmartHomePlatform/` depending on Xcode defaults)
     - `Models/` (Data models, e.g. `AbstractDevice.swift`)
     - `ViewModels/` (Business logic and state management)
     - `Views/` (SwiftUI screens)
     - `Adapters/` (Vendor-specific adapters)
     - `DAL/` (Device Abstraction Layer classes)
   - `Tests/`
     - `UnitTests/`
     - `IntegrationTests/`

3. **Dummy Code**:
   - Create a placeholder for `AbstractDevice` and a simple `DeviceType` enum.
   - Write a minimal SwiftUI `ContentView` with a text label like "Hello Smart Home!"

**Checkpoint**: Build and run on a simulator to confirm the scaffolding works.

---

### Sprint 1: Single Device Integration (Thermostat)

**Goal**: Implement a single end-to-end vendor integration (e.g., Nest) to validate the approach.

1. **OAuth2 Flow**:
   - If using `OAuthSwift`, set up the client ID, client secret in an `.xcconfig` or secure store.
   - Create a `NestOAuthManager` class that handles signing in, token refreshing, etc.

2. **Nest Adapter**:
   - Create `NestAdapter.swift` implementing a `SmartDeviceAdapter` protocol:
     ```swift
     protocol SmartDeviceAdapter {
         func initializeConnection(authToken: String) throws
         func fetchDevices() async throws -> [AbstractDevice]
         func updateDeviceState(deviceId: String, newState: DeviceState) async throws -> DeviceState
     }
     ```
   - In `NestAdapter`, handle the Nest-specific endpoints (e.g., GET `devices` from the Nest SDM API).

3. **Device Abstraction**:
   - Add a `Thermostat` subtype in the DAL (e.g., `ThermostatDAL.swift`) to unify reading/writing temperature values.

4. **UI Binding**:
   - In SwiftUI, create a `ThermostatListView` that shows discovered thermostats.
   - Let the user tap on a thermostat to open `ThermostatDetailView`, where they can set a new temperature.

5. **Keychain Storage**:
   - After obtaining an OAuth token, store it in Keychain using `KeychainAccess` or Apple's native APIs.

**Checkpoint**:
- Successfully log in with Nest credentials, see at least one thermostat, adjust the temperature from the app.

---

### Sprint 2: Add Lock & Light Integrations & UI Consolidation

**Goal**: Demonstrate the modular approach by adding integrations for locks (August/Yale) and lights (Philips Hue), and consolidating the main device view.

**Current Status:** ⏳ In Progress

1.  **Lock Integrations (August/Yale/SmartThings):**
    *   **Status:** ✅ Files Exist / Implementation Started (`AugustLockAdapter.swift`, `YaleLockAdapter.swift`, `SmartThingsAdapter.swift`)
    *   Implement adapters conforming to `SmartDeviceAdapter` (and potentially `LockAdapter`).
    *   Handle specific API endpoints, authentication (using `AugustTokenManager`, `SmartThingsTokenManager`, etc.), and data mapping to `LockDevice` / `AbstractDevice`.
    *   Define `Lock` type/operations in the DAL if not already present.
    *   **Note:** SmartThings token management (`SmartThingsTokenManager`, `SmartThingsWebhookHandler`) integration is complete. Further testing/verification of full adapter functionality is needed.

2.  **Dedicated Light Integration (e.g., Philips Hue):**
    *   **Status:** ⏳ **Next Task**
    *   Create `HueLightAdapter.swift` (or similar) conforming to `SmartDeviceAdapter`.
    *   Implement methods like `fetchDevices`, `getDeviceState`, `executeCommand` (mapping to `turnOn`, `turnOff`, `setBrightness`, etc.). Handle Hue authentication and API specifics.
    *   Map data to `LightDevice` / `AbstractDevice`.

3.  **UI Consolidation:**
    *   **Status:** ⏳ Pending
    *   Refactor/Update `ios/Views/DevicesView.swift` to display devices from *all* integrated adapters (Nest, August, Yale, SmartThings, Hue) fetched via `DeviceService`.
    *   Display devices in a unified list or grid (e.g., using device cards).
    *   The view should dynamically show appropriate controls based on the `AbstractDevice`'s underlying type (Thermostat, Lock, Light).
    *   Phase out the separate `LockListView.swift` and `ThermostatListView.swift`.

**Checkpoint**:
- Validate Nest thermostat control (from Sprint 1).
- Validate August/Yale/SmartThings lock control.
- **(Target)** Implement and validate Hue light control.
- **(Target)** Ensure `DevicesView.swift` displays all device types correctly from all adapters.

---

### Sprint 3: Multi-User & Role-Based Access

**Goal**: Introduce user management with roles (Property Manager, Tenant, Guest) and enforce access control based on these roles.

**Current Status:** ⏳ Upcoming / Foundational Components Exist

1.  **User Model:**
    *   **Status:** ✅ Exists (`Sources/Models/User.swift` defines roles: OWNER, PROPERTY_MANAGER, TENANT, GUEST and relevant properties).
    *   Refine model as needed for property/room assignments.

2.  **Authentication & User Management:**
    *   **Status:** ✅ Exists (`ios/Views/LoginView.swift`, `Sources/Services/UserManager.swift` handling login, tokens via `KeychainHelper`, `currentUser`).
    *   Integrate with backend if necessary for user persistence/validation.

3.  **Role Enforcement Logic:**
    *   **Status:** ⏳ Pending
    *   Implement logic (likely in `DeviceService` or ViewModels) to filter device visibility and control based on `UserManager.shared.currentUser.role` and associated `properties`/`assignedRooms`.

4.  **UI Adaptation:**
    *   **Status:** ⏳ Pending
    *   Ensure UI elements (buttons, views) adapt based on user role (e.g., hide admin features for tenants/guests).

**Checkpoint**:
- Ensure that a manager account can see all devices in a property, while a tenant sees only their assigned unit's devices. Guest access is appropriately limited.

---

### Sprint 4: Invitations & Tenant Management

**Goal**: Allow managers to invite tenants, link them to units/devices, and manage their access.

**Current Status:** ⏳ Upcoming / Models Exist

1.  **Invite Flow Implementation:**
    *   **Status:** ⏳ Pending
    *   Design and implement UI/logic for generating invites (links/codes) and handling tenant sign-up/linking.
    *   Requires backend support if invites are managed server-side.

2.  **Unit/Property Assignment Logic:**
    *   **Status:** ✅ Foundational Models Exist (`User.swift` includes `properties`, `assignedRooms`; `GuestAccess` struct has `validFrom`, `validUntil`, `deviceIds`).
    *   **Status:** ⏳ Logic Pending
    *   Solidify data model and implement logic for associating users with properties/units and ensuring device access is correctly scoped.

3.  **Revocation Mechanism:**
    *   **Status:** ⏳ Pending
    *   Implement UI and logic for managers to revoke tenant or guest access.

**Checkpoint**:
- A property manager can successfully invite a tenant, assign them to a unit, and later revoke their access. Tenant view is correctly scoped.

---

### Sprint 5: Caching & Performance

**Goal**: Implement caching to improve performance and avoid rate limits; establish polling or push notification strategies.

**Current Status:** ⏳ Upcoming / Partial Implementations Exist

1.  **Implement Caching Strategy:**
    *   **Status:** ⏳ Pending
    *   Design and implement a clear caching layer (in-memory or persistent) for device states.
    *   Define cache invalidation logic (time-based, event-based).

2.  **Polling / Push Strategy:**
    *   **Status:** ✅ Partial Push Exists (`SmartThingsWebhookHandler.swift`), ✅ Partial Rate Limiting Exists (`NestAdapter`, `SmartThingsRetryHandler`)
    *   **Status:** ⏳ Polling Pending
    *   Implement smart polling for adapters without push support.
    *   Ensure existing push handlers efficiently update cache/UI.
    *   Implement push for other adapters if available (e.g., Nest Pub/Sub).

**Checkpoint**:
- App performance remains acceptable with numerous devices. Rate limits are handled gracefully. Device states update reasonably quickly via cache, polling, or push.

---

### Sprint 6: Security & Settings

**Goal**: Enhance security (2FA, token handling) and refine settings.

**Current Status:** ⏳ Upcoming / Partial Implementations Exist

1.  **Two-Factor Authentication (2FA):**
    *   **Status:** ⏳ Pending
    *   Implement 2FA flow (likely requires backend support).

2.  **Robust Token Handling:**
    *   **Status:** ✅ Foundational Token Managers Exist (`NestOAuthManager`, `AugustTokenManager`, `SmartThingsTokenManager`, `UserManager` using `KeychainHelper`).
    *   **Status:** ⏳ Robust Error Handling Pending
    *   Ensure all adapters gracefully handle token expiry/refresh failures by prompting re-login.

3.  **Security Testing / Role Enforcement:**
    *   **Status:** ⏳ Pending
    *   Perform dedicated tests to ensure role permissions are strictly enforced.

4.  **Expand Settings:**
    *   **Status:** ✅ Basic View Exists (`SettingsView.swift` with logout/placeholders).
    *   **Status:** ⏳ Functionality Pending
    *   Flesh out `SettingsView.swift` with actual user preferences and account management features.

**Checkpoint**:
- Confirm sensitive operations require valid tokens/roles. 2FA implemented for relevant roles. Token errors are handled. Settings screen is functional.

---

### Sprint 7: UI/UX Polish

**Goal**: Refine the interface, improve design consistency, and enhance user experience.

**Current Status:** ⏳ Upcoming / Basic Views Exist

1.  **Implement Device Card UI:**
    *   **Status:** ✅ Core Views Exist (`ContentView`, `DevicesView`, `LoginView`, `DashboardView`, specific detail views).
    *   **Status:** ⏳ Device Card UI Pending
    *   Standardize device display using a card-style layout in `DevicesView` and potentially `DashboardView`.

2.  **Property/Unit Grouping/Navigation:**
    *   **Status:** ⏳ Pending
    *   Implement UI logic for managers to navigate between properties/units.

3.  **Animations & Feedback:**
    *   **Status:** ⏳ Pending
    *   Add visual feedback (loading states, transitions).

4.  **General Polish:**
    *   **Status:** ⏳ Pending
    *   Refine layouts, typography, iconography, and overall flow.

**Checkpoint**:
- The app presents a consistent, polished, and intuitive user experience.

---

### Sprint 8: Testing & Pilot Release

**Goal**: Conduct real-world testing, gather feedback, and prepare for release.

**Current Status:** ⏳ Upcoming / Test Structure Exists

1.  **Comprehensive Unit & Integration Tests:**
    *   **Status:** ✅ Test Directories Exist (`Tests/`, `AdaptersTests`, `ModelsTests`). ✅ Some test utilities exist (`LoadTestingUtility.swift` found in `Tests/ModelsTests/`).
    *   **Status:** ⏳ Coverage Pending
    *   Ensure sufficient test coverage for adapters, models, view models, services.
    *   Create end-to-end tests for key flows.

2.  **UI Tests:**
    *   **Status:** ⏳ Pending
    *   Implement UI tests for critical flows.

3.  **Beta Testing Setup:**
    *   **Status:** ⏳ Pending
    *   Prepare builds for TestFlight or other distribution.

4.  **Backend Load Testing (If applicable):**
    *   **Status:** ⏳ Pending
    *   Utilize/expand `LoadTestingUtility` if backend components exist.

5.  **Bug Fixing:**
    *   **Status:** ⏳ Ongoing as needed
    *   Address issues found during testing.

**Checkpoint**:
- The application is well-tested, stable, and ready for pilot deployment.

---

## Testing Strategy

1. **Unit Tests**:
   - Test each adapter with mock API responses.  
   - Test DAL transformations (lock/unlock success, thermostat setpoints).
2. **Integration Tests**:
   - End-to-end scenario: user logs in, fetches devices, toggles states, verifies the final device state.
3. **UI Tests**:
   - Use `XCTest` UI tests or SwiftUI's preview environment for basic flows (login → device list → device detail → control).
4. **Security Tests**:
   - Attempt unauthorized actions, ensure the system gracefully denies them.

---

## Deployment Steps

1. **App Store Registration**:
   - Create an App Store Connect entry, fill out app details and metadata.
2. **Provisioning Profiles**:
   - Set up distribution certificates in the Apple Developer portal.
3. **Build & Archive**:
   - Xcode → Product → Archive, then upload to the App Store or TestFlight.
4. **Review & Approval**:
   - Apple review might require you to provide demo accounts for them to test IoT device control.

---

## Maintenance & Ongoing Tasks

- **API Monitoring**: Third-party vendors might change endpoints or deprecate older versions; keep track of their developer announcements.
- **Security Patches**: Update libraries or implement new best practices regularly.
- **Feature Enhancements**: Over time, you may want deeper analytics, local control (Z-Wave/Zigbee), or integration with property management systems.


