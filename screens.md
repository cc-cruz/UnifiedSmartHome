# iOS App Screens Overview (`screens.md`)

## 1. Purpose

This document outlines the key screens required for the Unified Smart Home iOS application, derived from the `app-submission-steps.md` and `ui-design-tasks.md`. It serves as a guide for UI/UX design and development, providing a structured overview of the application's user interface.

## 2. Core Navigation & Context Management Screens

These screens are fundamental for user authentication and navigating the multi-tenancy hierarchy (Portfolio -> Property -> Unit).

*   **`LoginScreen`**
    *   **Purpose:** Allows users to enter their credentials (email, password) to authenticate.
    *   **Key Elements:** Email field, password field, login button, forgot password link, sign-up link (if applicable).
    *   **States:** Standard, loading, error (invalid credentials, network error).
*   **`AuthenticationInProgressScreen` / Loading Indicator**
    *   **Purpose:** Visual feedback while authentication or initial data loading (like user profile with roles) occurs post-login.
*   **`RoleSelectionScreen`** (Part of initial context setup - P0 Step 4)
    *   **Purpose:** If a user has multiple high-level roles not tied to a specific entity (e.g., SuperAdmin vs. standard User), this screen allows them to select their active role for the session. More commonly, this might be skipped if roles are derived from entity associations.
    *   **If Simplified:** Directly presents accessible Portfolios if roles are clear from login.
*   **`PortfolioSelectionScreen` / `PortfolioListView`** (Part of initial context setup - P0 Step 4)
    *   **Purpose:** Allows users with access to multiple Portfolios to select their active Portfolio.
    *   **Key Elements:** List of accessible Portfolios (name, potentially other identifiers), navigation to select a Portfolio.
    *   **States:** Loading, list of portfolios, empty state (no portfolios accessible/assigned), error state.
*   **`PropertySelectionScreen` / `PropertyListView`** (Part of initial context setup - P0 Step 4)
    *   **Purpose:** Allows users to select an active Property within the chosen Portfolio.
    *   **Key Elements:** List of Properties within the selected Portfolio (name, address snippet), navigation to select a Property.
    *   **States:** Loading, list of properties, empty state, error state.
*   **`UnitSelectionScreen` / `UnitListView`** (Part of initial context setup - P0 Step 4)
    *   **Purpose:** Allows users to select an active Unit within the chosen Property.
    *   **Key Elements:** List of Units within the selected Property (name, other identifiers), navigation to select a Unit (which then typically leads to a device view scoped to this unit).
    *   **States:** Loading, list of units, empty state, error state.
*   **Active Context Display / Switcher (Conceptual - Needs Design)**
    *   **Purpose:** Persistently display the currently active Portfolio, Property, and/or Unit to the user. Provide a mechanism to easily switch between previously accessed or available contexts without re-doing the full selection flow.
    *   **Location Ideas:** App header, dedicated section in a tab bar, slide-out menu, or within Settings.

## 3. Main Device Interaction Screens

These screens are where users primarily interact with their smart devices.

*   **`DevicesView` (Consolidated Device List Screen)**
    *   **Purpose:** Display a list/grid of all devices accessible to the user within their currently selected context (Portfolio, Property, or Unit).
    *   **Key Elements:** Navigation bar (with context title, refresh, optional add device button), device filters (All, Lights, Locks, etc.), search bar, list/grid of `DeviceRow`/`DeviceCard` components.
    *   **States:** Loading (initial, refresh), empty (no devices in context), list/grid of devices, error (failed to fetch devices).
    *   **Contextual Behavior:** Title and device list are scoped by `UserContextViewModel`. "Add Device" button visibility depends on user's role in the current context.
*   **`DeviceRow` / `DeviceCard` (Reusable Component within `DevicesView`)**
    *   **Purpose:** Visually represent a single device, its status, and provide quick controls.
    *   **Key Elements:** Device icon (type & state specific), device name, status text (e.g., "Locked", "On - 70%", "Offline"), room/unit name (optional), quick action controls (e.g., lock/unlock toggle, light on/off toggle).
    *   **States:** Online, Offline, Locked/Unlocked, On/Off, specific states for thermostats (Heating, Cooling), loading/updating (per device after command), error (per device command).
*   **`LockDetailView`**
    *   **Purpose:** Provide detailed information and controls for a specific lock device.
    *   **Key Elements:** Lock status display, lock/unlock buttons, battery status, access history, settings (remote control, auto-lock), rename/remove options (role-dependent).
    *   **Contextual Behavior:** Actions and settings visibility controlled by user's role for this lock's P/P/U context.
*   **`ThermostatDetailView`**
    *   **Purpose:** Detailed information and controls for a thermostat.
    *   **Key Elements:** Current temperature, target temperature, mode (Heat, Cool, Eco, Off), controls to adjust target temperature and mode, fan settings (if applicable), schedule (if applicable).
*   **`LightDetailView` (Conceptual - Needs Design)**
    *   **Purpose:** Detailed information and controls for a light.
    *   **Key Elements:** On/Off toggle, brightness slider/control, color picker (if applicable), temperature control (if applicable).
*   **`SwitchDetailView` (Conceptual - Needs Design)**
    *   **Purpose:** Detailed information and controls for a smart switch.
    *   **Key Elements:** On/Off toggle, potentially power consumption data or scheduling.
*   **Generic `DeviceDetailView` (Conceptual - Needs Design)**
    *   **Purpose:** A fallback detail view for device types without a custom detail screen, or a base structure.
    *   **Key Elements:** Device name, type, status, basic controls if discoverable, link to raw device data/settings.

## 4. Entity Management Screens (CRUD Operations)

Screens for users with appropriate permissions to manage Portfolios, Properties, and Units.

*   **`PortfolioManagementScreen`**
    *   **Sub-screens:** `PortfolioListScreen`, `PortfolioDetailView`, `CreateEditPortfolioScreen`.
    *   **Purpose:** Allow authorized users (e.g., SuperAdmins, designated Portfolio Creators) to view, create, edit (name, administrators), and delete Portfolios.
*   **`PropertyManagementScreen`**
    *   **Sub-screens:** `PropertyListScreen` (within a Portfolio context), `PropertyDetailView`, `CreateEditPropertyScreen`.
    *   **Purpose:** Allow authorized users (e.g., Portfolio Admins/Owners) to view, create, edit (name, address, managers), and delete Properties within a specific Portfolio.
*   **`UnitManagementScreen`**
    *   **Sub-screens:** `UnitListScreen` (within a Property context), `UnitDetailView`, `CreateEditUnitScreen`.
    *   **Purpose:** Allow authorized users (e.g., Property Managers) to view, create, edit (name, tenants, associated devices), and delete Units within a specific Property.

## 5. User & Role Management Screens

Screens for managing user access and roles within the multi-tenancy system.

*   **`UserProfileScreen`**
    *   **Purpose:** Display the logged-in user's profile information. Include a section to clearly list all their roles and associated entities (e.g., "Owner of Portfolio X," "Manager of Property Y").
    *   **Key Elements:** User details (name, email), list of role associations, logout button, link to app settings.
*   **`InviteUserToRoleScreen` / `AssignRoleToUserScreen` (Variant per role context)**
    *   **Purpose:** Allow authorized users to invite new users or assign roles to existing users for specific entities.
    *   **Contexts:** Adding Portfolio Admin to a Portfolio, Property Manager to a Property, Tenant to a Unit.
    *   **Key Elements:** User search/selection (email or name), role selection dropdown (if multiple roles can be assigned), entity context display, invite/assign button.
*   **`GuestAccessManagementScreen` (Optional - P0/P1 dependent)**
    *   **Purpose:** Allow authorized users (e.g., Tenants, Property Managers) to grant, view, modify, and revoke temporary guest access to specific devices or units.
    *   **Key Elements:** List of active/pending guest passes, create new guest pass (select device/unit, set validity period, generate access code/link).

## 6. In-App Purchase Screens (P1)

Screens related to the "$1 Compliance Pack" In-App Purchase.

*   **`CompliancePackOfferScreen` / Purchase Point**
    *   **Purpose:** Present the "Compliance Pack" IAP to the user, showing its benefits, price, and a button to initiate purchase.
    *   **Location:** Could be in Settings, a dedicated "Add-ons" section, or a contextual banner.
*   **`ComplianceFeatureView` (Placeholder if feature is stubbed)**
    *   **Purpose:** The screen or section the user accesses after purchasing the Compliance Pack. For P1, this might be a simple view stating "Compliance Report - Coming Soon" or displaying very basic information.
*   **`SettingsScreen` (Relevant IAP Action)**
    *   **Key Elements (IAP related):** "Restore Purchases" button.

## 7. General & Supporting Screens

*   **`SettingsScreen`**
    *   **Purpose:** General app settings, user account management, legal information, IAP restore.
    *   **Key Elements:** Links to User Profile, Notification Settings, Theme (Light/Dark mode if applicable), About, Privacy Policy, Terms of Service, Restore Purchases.
*   **`AddDeviceFlowScreens` (Conceptual - Multi-Step Flow)**
    *   **Purpose:** Guide the user through adding a new smart device to their account and associating it with the correct Unit/Property.
    *   **Potential Steps/Screens:**
        1.  `SelectDeviceTypeScreen` (Choose from Lock, Light, Thermostat, etc.)
        2.  `AssignToContextScreen` (Confirm/select the Property and Unit for the new device, based on current active context or user selection).
        3.  Device-specific setup/pairing screens (may involve web views for OAuth or specific SDK UIs).
        4.  `NameDeviceScreen` & Confirmation.
*   **`ErrorStateView` (Reusable Component / Full Screen)**
    *   **Purpose:** A generic, full-screen view to display significant errors when a primary function or screen cannot load (more severe than a banner).
    *   **Key Elements:** Error icon, clear error message, potential troubleshooting steps, retry button.

This list provides a comprehensive overview. The exact number and complexity of screens will evolve, but this forms a solid foundation for UI/UX design efforts. Priority should align with the P0, P1, P2 goals outlined in `app-submission-steps.md`. 