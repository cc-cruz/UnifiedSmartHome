
 UI_UX_GUIDE.md

```markdown
# UI/UX Guide

## Table of Contents
1. [Design Principles](#design-principles)
2. [App Navigation](#app-navigation)
3. [Device Card Layouts](#device-card-layouts)
4. [Property & Unit Organization](#property--unit-organization)
5. [User Roles & UI States](#user-roles--ui-states)
6. [Security & UX Considerations](#security--ux-considerations)
7. [Branding & Theming](#branding--theming)
8. [Internationalization & Accessibility](#internationalization--accessibility)

---

## Design Principles

1. **Consistency**: Use standard icons for locks, thermostats, and lights. Follow iOS Human Interface Guidelines.
2. **Simplicity**: Make primary actions (lock/unlock, on/off, set temperature) immediately accessible without extra taps.
3. **Familiarity**: Model the main UI after popular consumer smart home apps (e.g., Google Home) to reduce user learning curves.

---

## App Navigation

### High-Level Flow

1. **Login Screen**:
   - Simple email/password or single sign-on.  
   - For a manager account, display a property overview after login.  
   - For a tenant, jump directly to their devices.

2. **Property Overview (Manager Role)**:
   - A list or grid of properties (if multiple).
   - Tapping a property leads to a “property devices” view.

3. **Device List** (Tenant or Manager):
   - Each device is represented by a “card” or “tile.”
   - Show device type icon, name, and status (locked/unlocked, on/off, temperature).

4. **Device Detail Screen**:
   - Displays advanced controls and settings.  
   - E.g., thermostat detail might show a slider for temperature, mode toggles, schedule options.

5. **Settings / Profile**:
   - Manage personal details, vendor integrations, 2FA, role-based invites (for managers).

---

## Device Card Layouts

1. **Lock** Card:
   - Icon: A lock symbol that changes color or style when locked vs. unlocked.
   - Status text: “Locked” / “Unlocked.”
   - Action: One-tap toggle (if user role permits).
2. **Thermostat** Card:
   - Icon: A thermostat or temperature gauge.
   - Current temperature and target temperature displayed prominently.
   - Action: Tapping reveals more controls (up/down temperature adjustment).

3. **Light** Card:
   - Icon: Light bulb that’s filled if on, outline if off.
   - Action: Tap to toggle on/off, press and hold (or detail screen) for brightness/color.

4. **State Indicators**:
   - Use color coding (blue for cool, orange for heat, green for eco) to quickly convey states.

---

## Property & Unit Organization

- **Manager View**:
  - `PropertiesScreen` → Lists all properties (e.g., “Maple Apartments,” “Pinewood Complex”).
  - Tapping a property → lists units within that property (e.g., Unit 101, Unit 102).
  - Tapping a unit → device list for that unit.
- **Tenant View**:
  - Directly navigates to devices in their assigned unit.  
  - No ability to switch properties or see other units.

---

## User Roles & UI States

1. **Manager Role**:
   - Access to an “Administration” tab or screen where they can:
     - Invite users (tenants/guests).
     - Set roles.
     - Manage multiple properties.
   - Possibly see aggregated dashboards (e.g., total locks unlocked, energy usage).
2. **Tenant Role**:
   - Sees only their unit’s devices.
   - No access to others’ devices or property-wide settings.
3. **Guest Role**:
   - Possibly a read-only or limited-time role for short-term visitors or maintenance staff.
   - Lock access might be time-bound (e.g., unlocked only during a certain window).

---

## Security & UX Considerations

- **Lock Control Confirmation**:
  - Optionally, prompt user confirmation or require Face ID/Touch ID before unlocking a door.
- **Timeouts**:
  - For highly sensitive actions, consider short session timeouts or re-auth checks.
- **Notifications**:
  - Push notifications for critical events (e.g., “Door left unlocked!”) if user opts in.

---

## Branding & Theming

- **Color Palette**:
  - Light/dark modes to match iOS system setting.
  - Accent color for highlights (e.g., brand color).
- **Icons**:
  - Use SF Symbols or custom icons that match iOS design language.  
- **Typography**:
  - Stick to iOS default type styles (e.g., Title, Headline, Subheadline) for consistency.

---

## Internationalization & Accessibility

1. **Localization**:
   - Use `Localizable.strings` for all text so translations can be easily added.
2. **Accessibility Labels**:
   - Set `accessibilityLabel` for device toggles, buttons, icons.
   - Ensure color-blind-friendly contrasts for status indicators.
3. **Dynamic Type**:
   - Ensure the UI scales properly if the user has large text settings.


