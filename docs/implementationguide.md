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
   - Write a minimal SwiftUI `ContentView` with a text label like “Hello Smart Home!”

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
   - After obtaining an OAuth token, store it in Keychain using `KeychainAccess` or Apple’s native APIs.

**Checkpoint**:
- Successfully log in with Nest credentials, see at least one thermostat, adjust the temperature from the app.

---

### Sprint 2: Add Lock & Light Integrations

**Goal**: Demonstrate the modular approach by adding at least two more integrations, e.g., a lock (August/Yale) and a light (Philips Hue).

1. **Lock Integration**:
   - `LockAdapter.swift` to handle retrieving lock status (locked/unlocked).
   - The API might differ from Nest’s structure, so be sure to parse the JSON accordingly.
   - In the DAL, define a `Lock` type with `lock()` and `unlock()` methods.

2. **Light Integration**:
   - `LightAdapter.swift` for Hue or another brand.
   - Implement methods like `turnOn()`, `turnOff()`, `setBrightness()`, etc.
   - In SwiftUI, create a `LightListView` that displays lights in a grid or list, and a detail view for color/brightness if supported.

3. **UI Consolidation**:
   - Consider a single “Devices” screen that merges thermostats, locks, and lights. Each item is a tile in a grid or a row in a list.

**Checkpoint**:
- Validate each device type can be controlled end-to-end without interfering with other types.

---

### Sprint 3: Multi-User & Role-Based Access

**Goal**: Introduce user management with roles (Property Manager, Tenant, Guest).

1. **User Model**:
   - Create a `User` struct/class with fields: `id`, `email`, `role`, etc.

2. **Auth Screen**:
   - SwiftUI-based login screen that sets `UserSession.shared.currentUser` upon success.
   - If using a backend for user auth, add endpoints like `/login` or leverage Firebase Auth.

3. **Role Enforcement**:
   - In your device fetching methods, filter out devices the current user is not allowed to see.
   - For locks, only let users with `manager` or `tenant` roles toggle lock states for assigned units.

4. **UI States**:
   - If a `guest` user logs in, show only the devices they’re permitted to see/operate (possibly time-limited).

**Checkpoint**:
- Ensure that a manager account can see all devices in a property, while a tenant sees only their assigned unit’s devices.

---

### Sprint 4: Invitations & Tenant Management

**Goal**: Managers can invite tenants, link them to specific units, and remove them if needed.

1. **Invite Flows**:
   - Provide an “Invite Tenant” button for property managers.
   - This might generate a temporary link or code, which the tenant uses to sign up.

2. **Unit / Property Assignment**:
   - Create a data model linking `userId -> propertyId -> deviceIds`.
   - Ensure new tenants only see devices relevant to their unit.

3. **Revocation**:
   - Implement a screen or a function that revokes tenant access (e.g., sets their account to inactive).

**Checkpoint**:
- A property manager can add and remove tenants, controlling which devices they can see.

---

### Sprint 5: Caching & Performance

**Goal**: Implement local caching to avoid rate limit issues and speed up repeated device queries.

1. **In-Memory Cache**:
   - A singleton or environment object that stores `deviceId -> DeviceState` for quick access.
   - On app launch, we fetch states from cache first, then refresh from the APIs.

2. **Polling Schedule**:
   - For devices that don’t have push updates, poll at intervals (e.g., 15-30 seconds or user-initiated).
   - Add logic to back off if errors or rate-limit warnings are received.

3. **Push Subscriptions** (if vendor-supported):
   - Nest may support event-based updates (webhooks). Integrate that logic if we have a backend to receive them.
   - Alternatively, if purely client-based, we need silent push or background fetch.

**Checkpoint**:
- Verify the app handles many devices without hitting rate limits or timing out.

---

### Sprint 6: Security & Settings

**Goal**: Increase application security and resilience.

1. **Two-Factor Authentication (2FA)**:
   - Integrate a 2FA flow for manager or admin logins. Could be via SMS or authenticator apps.
2. **OAuth Error Handling**:
   - Handle token refresh failures gracefully: if a token expires, prompt the user to re-authenticate.
3. **Security Audits**:
   - Attempt calling lock endpoints with a non-manager account. Ensure the system returns an error or denies access.

**Checkpoint**:
- Confirm that all sensitive paths (e.g., lock/unlock) require valid tokens and correct user roles.

---

### Sprint 7: UI/UX Polish

**Goal**: Refine the interface, enhance design consistency, and ensure a pleasant user experience.

1. **Device Cards**:
   - Use SwiftUI’s card-style layout. Show device name, icon, current status. Tapping opens a detailed view.
2. **Grouping by Property**:
   - For property managers with multiple buildings, add a top-level screen to select the property or see an overview.
3. **Animations & Feedback**:
   - Give immediate visual feedback when user toggles a device. Show loading spinners or transition animations.

**Checkpoint**:
- The app feels more polished and user-friendly; multiple device types can be managed seamlessly.

---

### Sprint 8: Testing & Pilot Release

**Goal**: Conduct real-world tests with a pilot group, gather feedback, and finalize for a production release.

1. **Beta Testing**:
   - Use TestFlight or an internal distribution method to let real property managers/tenants try the app.
   - Gather usage data and crash logs.
2. **Load Testing** (if using a backend):
   - Simulate hundreds of properties with thousands of devices to ensure stable performance.
3. **Bug Fixes & Polishing**:
   - Address any user feedback on confusing flows, slow performance, or missing features.

**Checkpoint**:
- A stable MVP release is ready. Proceed with marketing or partnerships.

---

## Testing Strategy

1. **Unit Tests**:
   - Test each adapter with mock API responses.  
   - Test DAL transformations (lock/unlock success, thermostat setpoints).
2. **Integration Tests**:
   - End-to-end scenario: user logs in, fetches devices, toggles states, verifies the final device state.
3. **UI Tests**:
   - Use `XCTest` UI tests or SwiftUI’s preview environment for basic flows (login → device list → device detail → control).
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


