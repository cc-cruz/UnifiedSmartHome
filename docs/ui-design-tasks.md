# UI Design Tasks: Consolidated Device View (Figma)

## 1. Goal

To create high-fidelity, component-based designs in Figma for the main consolidated device list screen (`DevicesView`) and the individual device representation (`DeviceRow` / Device Card), ensuring consistency, usability, and adherence to iOS Human Interface Guidelines (HIG). These designs will serve as the blueprint for the SwiftUI implementation.

## 2. Core Design Principles (FAANG Level Best Practices)

*   **Clarity & Intuitiveness:** Users should immediately understand device status and how to perform primary actions. Prioritize information and actions based on user goals (e.g., checking lock status, turning off a light).
*   **Consistency:** Maintain visual and interactive consistency across all device types and states. Adhere strictly to iOS HIG for navigation patterns, typography, iconography, and control types.
*   **Efficiency:** Minimize taps required for common actions (e.g., toggling lights/locks directly from the list view).
*   **Feedback:** Provide clear visual feedback for user interactions (taps, state changes) and system status (loading, errors, online/offline).
*   **Atomic Design / Componentization:** Design reusable components (icons, buttons, status indicators, the device card/row itself) to ensure consistency and streamline future updates. Define variants for different states.
*   **Accessibility (WCAG AA+):** Design for inclusivity from the start. Consider color contrast, dynamic type support, touch target sizes, and provide clear labels for assistive technologies.
*   **User Roles (Anticipation):** While full role implementation is Sprint 3, design with the understanding that controls/visibility might differ for Managers vs. Tenants. Show disabled states clearly.

## 3. Task Breakdown

### 3.1. Overall `DevicesView` (Consolidated Device List Screen)

*   **Task 3.1.1: Define Layout Strategy**
    *   **Options:** Standard List (`List`) vs. Grid (`LazyVGrid`).
    *   **Action:** Design mockups for *both* layouts. Evaluate pros/cons (Information density, scannability, scalability with many devices, visual appeal). Recommend one approach, but having both explorations is valuable.
    *   **Consider:** How many devices are typically expected? Is seeing more devices at once (Grid) more important than detailed status text (List)?
*   **Task 3.1.2: Design Navigation Bar / Header**
    *   **Elements:** Screen Title (`"Devices"` or similar), Refresh Button/Interaction (standard pull-to-refresh is implemented, but explicit button might be needed).
    *   **Future:** Consider placement for potential filtering or sorting controls (even if not implemented in this sprint).
*   **Task 3.1.3: Design Loading State**
    *   **Scenario:** Initial loading when the screen appears and the device list is empty.
    *   **Action:** Create a visually appealing loading state (e.g., using placeholder shimmer effects for rows/cards, or a centered progress indicator). Avoid blocking the entire UI unnecessarily if possible.
*   **Task 3.1.4: Design Empty State**
    *   **Scenario:** Loading completes, but no devices are found/configured for the user.
    *   **Action:** Design a clear, friendly message explaining the state (e.g., "No devices found", "Add your first device via Settings") with potentially an illustrative icon. Include guidance (e.g., "Pull down to refresh").
*   **Task 3.1.5: Design Global Error State**
    *   **Scenario:** Failure to load the list of devices (e.g., network error affecting `DeviceService.getAllDevices`).
    *   **Action:** Design how this error is communicated (e.g., the current implementation uses a banner at the top of the list; refine this design). Ensure it's clear and potentially offers a retry action.

### 3.2. `DeviceRow` / Device Card Component

*   **Task 3.2.1: Define Base Structure & Layout**
    *   **Action:** Create a reusable Figma component for the device representation (whether a list row or a grid card). Define padding, spacing, and arrangement of core elements (Icon, Info Area, Controls Area).
*   **Task 3.2.2: Design Information Display Area**
    *   **Elements:** Device Name (Primary Text), Status/Type Text (Secondary Text), Room Name (Tertiary/Optional Text).
    *   **Action:** Define typography styles (using iOS HIG Text Styles like Headline, Subheadline, Caption) and standard text colors (primary, secondary). Ensure clear visual hierarchy. Define truncation/wrapping behavior for long names/statuses.
*   **Task 3.2.3: Design Iconography**
    *   **Action:** Define specific icons (recommend SF Symbols for consistency) for each device type (Lock, Light, Thermostat, Switch, Generic/Unknown). Define variants for key states (e.g., locked vs. unlocked icon, light on vs. off icon).
*   **Task 3.2.4: Design Visual States (Crucial)**
    *   **Action:** Create variants or separate mockups within Figma demonstrating *all* relevant visual states for the *entire* row/card and its internal elements:
        *   **Online:** Default appearance.
        *   **Offline:** How is this visually indicated? (e.g., Reduced opacity for the whole row/card? Grayscaled icon? Explicit "Offline" text badge?). Current implementation uses opacity + red text. Refine this.
        *   **Lock States:** Locked, Unlocked, (Optional: Jammed). Show corresponding icon style/color changes.
        *   **Light States:** On, Off. Show icon style change. Show brightness percentage clearly if available and `On`. (Optional: Subtle indication of color/temp if possible without clutter).
        *   **Thermostat States:** Heating (e.g., orange color accent?), Cooling (e.g., blue accent?), Eco, Off/Idle. Display current and target temperatures clearly.
        *   **Switch States:** On, Off.
        *   **Loading/Updating State (Per Device):** If a command is sent, how does the specific row/card indicate it's processing? (e.g., subtle spinner near controls, temporary disablement of controls).
        *   **Error State (Per Device):** If a command fails for *this specific device*, how is that shown temporarily? (e.g., brief shake animation? Temporary error icon/message near controls?).
*   **Task 3.2.5: Design Interactive Controls**
    *   **Action:** Define the appearance and placement of controls within the row/card for each device type (based on the current implementation):
        *   **Lock:** Lock/Unlock Button (Icon-based). Ensure adequate touch target size (min 44x44 pts recommended by HIG). Show disabled state visually when offline or action is not possible.
        *   **Light:** On/Off Toggle. Consider interaction for brightness/color (e.g., does tapping the row navigate to detail, or is there a separate icon/button for detail?). Define disabled state.
        *   **Switch:** On/Off Toggle. Define disabled state.
        *   **Thermostat:** Placeholder currently. Define basic controls (e.g., +/- buttons for target temp? Tap action for detail view?). Define disabled state.
    *   **Feedback:** Define visual feedback for tapping controls (e.g., highlight state).
*   **Task 3.2.6: Define Navigation Interaction**
    *   **Action:** Specify if tapping the main body of the row/card navigates to a detail screen. If so, indicate this visually (subtle chevron?). If not, ensure controls are clearly the only interactive elements.

### 3.3. Cross-Cutting Concerns

*   **Task 3.3.1: Define Color Palette**
    *   **Action:** Specify primary, secondary, background, and accent colors. Define semantic colors (error, warning, success, informational, heating, cooling). Provide variants for Light and Dark Modes. Ensure all color combinations meet WCAG AA contrast ratios.
*   **Task 3.3.2: Define Typography Scale**
    *   **Action:** Document the usage of iOS Text Styles (Large Title, Title 1/2/3, Headline, Body, Callout, Subhead, Footnote, Caption 1/2) for different UI elements.
*   **Task 3.3.3: Define Icon Library**
    *   **Action:** Create a reference sheet showing the specific SF Symbols (or custom icons) used for each device type and state.
*   **Task 3.3.4: Accessibility Annotations**
    *   **Action:** Add notes or annotations specifying accessibility labels for interactive elements (buttons, toggles) and informative labels for icons/status indicators. Note considerations for Dynamic Type support.

## 4. Deliverables

*   Figma file containing:
    *   High-fidelity mockups of the `DevicesView` (List and/or Grid layout).
    *   Mockups showing `DevicesView` in Loading, Empty, and Error states.
    *   A well-structured `DeviceRow` / Device Card component with variants covering all relevant device types and their visual states (Online, Offline, Locked, Unlocked, On, Off, Brightness Levels, Thermostat Modes, etc.).
    *   Defined Color Palette (Light/Dark) and Typography styles applied consistently.
    *   Iconography reference.
    *   (Optional) Basic clickable prototype demonstrating navigation and state changes.

## 5. Next Steps

*   Share Figma file/link with the development team.
*   Discuss designs and gather feedback, iterating as needed.
*   Developer uses the "Inspect" tab and defined components to implement the UI in SwiftUI. 