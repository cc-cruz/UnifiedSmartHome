# Unified Smart Home App

A comprehensive iOS application for managing various smart home devices through a unified interface. This implementation focuses on the Lock Abstraction Layer and UI components.

## Project Structure

The project follows a clean architecture approach with clear separation of concerns:

### Core Layers

- **Models**: Data structures representing devices and their states
- **DAL (Device Abstraction Layer)**: Protocols and implementations for device operations
- **Adapters**: Vendor-specific implementations that connect to device APIs
- **Services**: Cross-cutting concerns like security, networking, and analytics
- **ViewModels**: Business logic and state management for UI components
- **Views**: SwiftUI components for user interaction

### Key Components

#### Lock Management System

- **LockDAL**: Abstraction layer for lock operations with security checks
- **LockDevice**: Model representing a smart lock with state management
- **LockAdapter**: Protocol for vendor-specific lock implementations
- **AugustLockAdapter**: Implementation for August smart locks
- **LockViewModel**: Business logic for lock operations and UI state
- **LockListView**: UI for displaying and controlling locks
- **LockDetailView**: Detailed view for individual lock management

#### Supporting Services

- **SecurityService**: Handles permission checks and security validations
- **AuditLogger**: Tracks security-sensitive operations
- **AnalyticsService**: Collects usage data for analysis
- **NetworkService**: Manages API communication
- **UserManager**: Handles user authentication and permissions
- **AugustTokenManager**: Manages authentication with August API

## Architecture Decisions

1. **Protocol-Based Abstraction**: All device interactions are defined through protocols, allowing for easy addition of new device types and vendors.

2. **Security-First Approach**: Lock operations require proper authentication and are logged for audit purposes.

3. **MVVM Pattern**: Clear separation between UI (Views), business logic (ViewModels), and data (Models).

4. **Dependency Injection**: Services and adapters are injected into ViewModels for better testability.

5. **Async/Await**: Modern Swift concurrency for handling asynchronous operations.

## Implementation Details

### Lock Abstraction Layer

The Lock Abstraction Layer provides a unified interface for interacting with different types of smart locks:

```swift
protocol LockDALProtocol {
    func lockDevice(id: String) async throws
    func unlockDevice(id: String) async throws
    func getLockStatus(id: String) async throws -> LockDevice.LockState
    func getAccessHistory(id: String, limit: Int) async throws -> [LockDevice.LockAccessRecord]
}
```

### Vendor Adapters

Vendor-specific adapters implement the `LockAdapter` protocol:

```swift
protocol LockAdapter {
    func initialize() async throws
    func fetchLocks() async throws -> [LockDevice]
    func getLockStatus(id: String) async throws -> LockDevice.LockState
    func controlLock(id: String, operation: LockDevice.LockOperation) async throws
}
```

### Security Measures

All lock operations go through security checks:

```swift
class SecurityService {
    func validateUserForOperation(userId: String, deviceId: String, operation: String) async throws -> Bool
    func checkPermission(userId: String, permission: Permission) async -> Bool
}
```

## Project Status

This project follows an 8-sprint plan outlined in `docs/implementationguide.md`.

*   **Sprint 1: Initial Setup & Thermostat**
    *   **Status:** ✅ Completed
    *   **Key Deliverables:** Basic project structure, Nest Thermostat integration (`NestAdapter.swift`).
*   **Sprint 2: Locks, Lights & UI Consolidation**
    *   **Status:** ⏳ In Progress
    *   **Completed:** Adapters for August (`AugustLockAdapter.swift`), Yale (`YaleLockAdapter.swift`), and SmartThings (`SmartThingsAdapter.swift`) are implemented (pending full testing/verification). SmartThings token management complete.
    *   **Next Steps:**
        1.  Implement dedicated Light Adapter (e.g., Philips Hue).
        2.  Consolidate device display into `DevicesView.swift`.
*   **Sprint 3: Multi-User & Role-Based Access**
    *   **Status:** ⏳ Upcoming
    *   **Goal:** Introduce roles (Manager, Tenant, Guest) and enforce access control. Foundational components (`User.swift`, `UserManager.swift`) exist.
*   **Sprint 4: Invitations & Tenant Management**
    *   **Status:** ⏳ Upcoming
    *   **Goal:** Implement tenant invitation and access management flows.
*   **Sprint 5: Caching & Performance**
    *   **Status:** ⏳ Upcoming
    *   **Goal:** Implement caching, polling/push notifications. Some rate limiting and webhook handling exists (`SmartThingsWebhookHandler.swift`).
*   **Sprint 6: Security & Settings**
    *   **Status:** ⏳ Upcoming
    *   **Goal:** Enhance security (2FA), refine token handling, and build out `SettingsView.swift`.
*   **Sprint 7: UI/UX Polish**
    *   **Status:** ⏳ Upcoming
    *   **Goal:** Refine UI, implement standard device cards, improve navigation.
*   **Sprint 8: Testing & Pilot Release**
    *   **Status:** ⏳ Upcoming
    *   **Goal:** Comprehensive testing and release preparation. `Tests/` directory structure exists.

## Future Enhancements (Beyond Current Scope)

1.  **Additional Device Types**: Support for device categories beyond thermostats, locks, and lights (e.g., cameras, sensors, smart plugs).
2.  **Advanced Automation Rules**: A more sophisticated rule engine with complex triggers and conditions.
3.  **Offline Mode**: Robust support for device control and status updates without internet connectivity.
4.  **HomeKit Integration**: Native integration with Apple's HomeKit framework.
5.  **Platform Expansion**: Potential Android or Web versions.

## Getting Started

1. Clone the repository
2. Open the project in Xcode
3. Build and run on an iOS simulator or device

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+ 

## MongoDB Atlas Production Setup

We provision production Atlas resources via the script `backend/scripts/atlas_provision.sh`.

1. Install the Atlas CLI and run `atlas auth login`.
2. Export required parameters and run the script:
   ```bash
   export ORG_ID=<your_org_id>
   export IP_RENDER=<render_outbound_ip_or_cidr>
   export IP_OFFICE=<office_vpn_cidr>
   export DB_PASS=<strong_password>
   ./backend/scripts/atlas_provision.sh
   ```
3. Once complete, copy the SRV URI printed at the end and add it as `MONGODB_URI` in Render’s **Production Environment Group**.
4. Rotate DB user passwords using `atlas dbusers update` and update the secret in Render. IP allow-lists can be modified via `atlas accessLists create|delete`.

### Seeding reference data

Run once after the cluster is reachable:
```bash
cd backend
npm run seed
```
This seeds role documents, a demo portfolio hierarchy, and walks you through creating the first SuperAdmin account. 

### Enabling Datadog logging

1. Obtain an API key from your Datadog dashboard (Integrations → APIs).
2. In Render → Environment tab, add `DATADOG_API_KEY=<your_key>` and (optionally) `LOG_LEVEL`.
3. Deploy or restart the service – Pino will auto-detect the key and begin forwarding logs to Datadog. 

## CI/CD

This repository includes a GitHub Actions workflow (`.github/workflows/backend.yml`) that:
1. Runs on every push or PR targeting `main`.
2. Installs backend dependencies and executes tests.
3. If the build originates from the `main` branch, it POSTS to a Render deploy hook stored in the secret `RENDER_DEPLOY_HOOK` to trigger a production deployment.

### Setting up the deploy hook
1. In Render, open your backend service → **Deploy Hooks** and generate a new hook.
2. In GitHub → **Settings → Secrets → Actions**, add `RENDER_DEPLOY_HOOK` with the URL string.
3. Merge to `main` and GitHub Actions will automatically deploy the new image.

### Local Docker build
To build the backend container locally:
```bash
docker build -t unified-smart-home-backend -f backend/Dockerfile .
```
Run locally with:
```bash
docker run --env-file backend/env.example -p 3000:3000 unified-smart-home-backend
``` 

## iOS Fastlane Setup (Session Authentication)

1. Install Fastlane:
   ```bash
   brew install fastlane   # or sudo gem install fastlane
   ```
2. Generate a 30-day session token:
   ```bash
   fastlane spaceauth -u YOUR_APPLE_ID_EMAIL
   ```
   Enter the 2FA code → copy the entire token that starts with `"DES…"`.
3. Store the token in your shell or CI secrets:
   ```bash
   export FASTLANE_SESSION="DES123…"
   ```
4. Optional: Set `MATCH_PASSWORD` if you use `match` encryption.
5. Run lanes:
   ```bash
   cd ios
   fastlane certs   # fetch/renew provisioning profiles
   fastlane build   # builds .ipa
   fastlane beta    # uploads to TestFlight
   ```
6. When the session expires, regenerate with `fastlane spaceauth` and update the secret.

Upgrade path: once the Apple account is converted to Organization, switch to App Store Connect API-key authentication. 