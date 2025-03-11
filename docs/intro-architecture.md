# Architecture Overview

## Table of Contents
1. [Introduction](#introduction)
2. [System Components](#system-components)
3. [Application Layers](#application-layers)
4. [Data Flows](#data-flows)
5. [Scalability Considerations](#scalability-considerations)
6. [Security Considerations](#security-considerations)
7. [Deployment Strategies](#deployment-strategies)
8. [Future Extensions](#future-extensions)

---

## Introduction
This document describes the high-level architecture for our **multi-vendor Smart Home Platform**, focusing on how we unify various IoT devices (locks, thermostats, lights, etc.) from different vendors under a single mobile (iOS) application. By abstracting vendor APIs into a modular "adapter" layer and normalizing device data, we can deliver a cohesive control and monitoring experience for property managers and tenants.

**Key Requirements**:
1. **Modularity**: Easily add or remove vendor integrations without affecting the core application.
2. **Scalability**: Support hundreds or thousands of devices and multiple properties without slow performance or hitting rate limits.
3. **Security & Privacy**: Especially critical for locks, cameras, and personal data (tenants, property owners).
4. **Multi-Tenant / Role-Based Access**: Different user types (property managers, tenants, guests) require different levels of control.

---

## System Components

1. **iOS Client Application**
   - **Front-End**: SwiftUI-based interface for viewing and controlling devices.
   - **Authentication Layer**: Login, user management (property manager vs tenant), and role-based UI logic.
   - **Vendor Integrations**: Handles OAuth flows or delegates them to a server (if we have a backend) to retrieve tokens.

2. **Cloud / Backend (Optional for MVP)**
   - **User and Device State Management**: If you want to offload data storage and device state caching from the client.
   - **Webhooks / Push Notification Handling**: Central place for receiving vendor push events (e.g., Nest Pub/Sub).
   - **Analytics and Reporting**: Aggregates device usage over time, tracks energy consumption, etc.

3. **Vendor Adapters**
   - Each adapter is responsible for **translating** vendor-specific endpoints, data formats, and authentication into a standardized **Device Abstraction Layer**.

4. **Device Abstraction Layer (DAL)**
   - Normalizes capabilities across devices (on/off, locked/unlocked, temperature setpoints, etc.).
   - Ensures the rest of the application can interact with "generic" lock, thermostat, or light objects without worrying about the vendor-specific details.

5. **Data Storage / Databases**
   - **Local**: iOS Keychain for storing tokens. Potentially Core Data or SQLite for ephemeral device state caches.
   - **Backend**: If used, you might have a PostgreSQL or MongoDB instance for persistent storage of user profiles, device relationships, and logs.

---

## Application Layers

+-----------------------------+ | iOS UI Layer | | (SwiftUI + app navigation) | +-------------+---------------+ | v +-----------------------------------+ | Device Control Layer | | (Business logic, domain models) | +----------------+------------------+ | v +-----------------------------------------------+ | Device Abstraction Layer (DAL) | | [LockDAL, ThermostatDAL, LightDAL, etc.] | +----------------+------------------------------+ | v +-----------------------------------------------+ | Vendor Adapters (modular) | | [Adapter - Nest, Adapter - SmartThings, etc.] | +----------------+------------------------------+ | v <--- OAuth2 / HTTP / Webhooks / SDKs --->



### 1. iOS UI Layer
- **SwiftUI** views that present device data, allow user interactions (turning on lights, locking doors), and handle user login/registration.

### 2. Device Control Layer
- Core business logic that decides how to interpret user requests (e.g., user taps "lock" → calls lock() on the appropriate device object).
- **Role-based checks** to ensure the user is authorized for the requested action.

### 3. Device Abstraction Layer (DAL)
- Mediates between the high-level business logic and the vendor-specific API calls.
- Provides generic data models (`AbstractDevice`, `DeviceState`) for various device types.

### 4. Vendor Adapters
- **Small modules** that handle vendor endpoints, token refresh flows, rate-limited calls, etc.
- Each adapter implements a standardized interface (e.g., `SmartDeviceAdapter`), exposing methods like `fetchDevices()`, `updateDeviceState()`, etc.

---

## Data Flows

1. **User Authentication**  
   - User logs into the iOS app (via email/password or third-party SSO).  
   - Session tokens are stored securely on the client.  

2. **Vendor Integration Setup**  
   - User chooses a vendor to integrate (e.g., Nest).  
   - OAuth2 flow occurs, obtains refresh/access tokens, stored in iOS Keychain or a backend.  

3. **Device Discovery**  
   - On app launch, we fetch the list of devices from each integrated vendor using the relevant adapter.  
   - The DAL normalizes them into an in-memory list of `AbstractDevice` objects.  

4. **Device Control & Monitoring**  
   - When a user interacts (e.g., toggles a light), the request goes to the adapter method.  
   - The adapter updates the device via the vendor API, and the new state is returned and displayed in the UI.  

5. **Polling vs. Push**  
   - **Polling**: The app periodically calls `adapter.refreshDeviceStates()` if push is not available.  
   - **Push/Webhooks**: If the vendor supports push updates, the adapter or server updates local state upon receiving them.  

---

## Scalability Considerations

- **Rate Limit Handling**:
  - Keep track of how often we poll each vendor. Exponential backoff if nearing limits.
- **Caching**:
  - Cache device states locally to avoid redundant calls for the same data.
- **Sharding by Property** (Backend Only):
  - If we move to a microservices architecture, we can scale horizontally by splitting load across multiple servers, each responsible for subsets of properties or vendors.

---

## Security Considerations

1. **Lock & Camera Security**:
   - Must ensure robust encryption (TLS) for all communication, especially commands that lock/unlock doors.
   - Apply 2FA for property managers with lock access.
2. **Token Storage**:
   - Use the iOS Keychain to store OAuth tokens.
   - Never store tokens in plain text or in an unsecured local database.
3. **Role-Based Access Controls**:
   - Enforce at the business logic layer and the UI layer. Tenants should never see or control devices outside their unit.

---

## Deployment Strategies

1. **MVP (Client-Focused)**:
   - The iOS app performs most of the logic and direct API calls.
   - No dedicated backend except for user auth (e.g., Firebase or Auth0).
2. **Full-Stack Approach**:
   - A dedicated backend for user management, device polling, and bridging push notifications.
   - Possibly host on AWS, GCP, or Azure with container orchestration if needed.



## Future Extensions

1. **Local Protocols (Z-Wave/Zigbee)**:
   - Requires an on-prem hub or bridging device to handle local network protocols.
2. **Analytics & Reporting**:
   - Gather usage data (e.g., average daily temperature settings) for property managers.
3. **Integration with Property Management Systems**:
   - Expose an API or webhooks to platforms like Yardi, AppFolio for end-to-end property management.


