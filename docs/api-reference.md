# API Integration Reference

## Table of Contents
1. [Overview](#overview)
2. [Common API Patterns](#common-api-patterns)
3. [Nest Adapter Details](#nest-adapter-details)
4. [SmartThings Adapter Details](#smartthings-adapter-details)
5. [August/Yale Lock Adapter](#augustyale-lock-adapter)
6. [Philips Hue Adapter](#philips-hue-adapter)
7. [Handling OAuth2 Tokens](#handling-oauth2-tokens)
8. [Error Handling & Retries](#error-handling--retries)
9. [Vendor-Specific Tips](#vendor-specific-tips)

---

## Overview
This document provides detailed reference for each vendor integration. Adapters transform vendor-specific JSON payloads into a normalized format (`AbstractDevice`, `DeviceState`) and implement standard interface methods (e.g., `fetchDevices()`, `updateDeviceState()`). We also cover **OAuth2** best practices and common pitfalls when dealing with IoT APIs.

---

## Common API Patterns

1. **OAuth2 Authentication**:
   - Typically involves obtaining an `access_token` + `refresh_token`.
   - `access_token` is valid for a short period (minutes to hours).
   - `refresh_token` is used to get a new `access_token` without requiring user re-login.

2. **Device Metadata Endpoints**:
   - Usually: `GET /devices`, which returns an array of devices in JSON.
   - Look for fields like `device_id`, `device_type`, `name`, `capabilities`.

3. **State Update Endpoints**:
   - Usually: `POST /devices/{id}/commands` or `PATCH /devices/{id}/state`.
   - Varies by vendor (some have dedicated endpoints for each capability).

4. **HTTP Status Codes**:
   - **200** or **201** → success.
   - **401** → invalid or expired token; trigger refresh logic.
   - **429** → rate-limited; implement backoff.

---

## Nest Adapter Details

### Endpoints

- **Device Discovery**: `GET https://smartdevicemanagement.googleapis.com/v1/enterprises/{project-id}/devices`
- **Update State** (Thermostat example):  
  `POST https://smartdevicemanagement.googleapis.com/v1/enterprises/{project-id}/devices/{device-id}:executeCommand`
  with a body like:
  ```json
  {
    "command": "sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
    "params": {
      "heatCelsius": 23.0
    }
  }
  ```

### JSON Parsing

- **deviceTraits**: The traits field indicates capabilities:
  - `sdm.devices.traits.ThermostatTemperatureSetpoint`
  - `sdm.devices.traits.LockUnlock` (if locks are present, though Nest primarily has thermostats/cameras).
- **Temperature Units**: The Nest API might return Celsius. Convert to Fahrenheit if needed by the app.

### OAuth2 Setup

- **Client ID & Secret** from Google Cloud console.
- **Scopes**: Typically `https://www.googleapis.com/auth/sdm.service`.
- **Token URI**: `https://accounts.google.com/o/oauth2/token`.

## SmartThings Adapter Details

### Current Implementation Status
- [x] OAuth2 Authentication Flow
- [x] Device Discovery
- [x] Basic Device Control
- [x] Error Handling
- [x] Audit Logging
- [x] Rate Limiting
- [x] Webhook Support
- [x] Device Grouping
- [x] Scene Support

### API Endpoints
- **Get Devices**: `GET https://api.smartthings.com/v1/devices`
- **Device Details**: `GET https://api.smartthings.com/v1/devices/{deviceId}/status`
- **Command**: `POST https://api.smartthings.com/v1/devices/{deviceId}/commands`
- **Webhooks**: `POST https://api.smartthings.com/v1/webhooks`
- **Groups**: 
  - `GET https://api.smartthings.com/v1/groups`
  - `POST https://api.smartthings.com/v1/groups`
  - `PUT https://api.smartthings.com/v1/groups/{groupId}`
  - `DELETE https://api.smartthings.com/v1/groups/{groupId}`
  - `POST https://api.smartthings.com/v1/groups/{groupId}/commands`
- **Scenes**:
  - `GET https://api.smartthings.com/v1/scenes`
  - `POST https://api.smartthings.com/v1/scenes`
  - `PUT https://api.smartthings.com/v1/scenes/{sceneId}`
  - `DELETE https://api.smartthings.com/v1/scenes/{sceneId}`
  - `POST https://api.smartthings.com/v1/scenes/{sceneId}/execute`

### Authentication
- OAuth2 flow with refresh token support
- Token storage in Keychain
- Automatic token refresh
- Environment variables required:
  - `SMARTTHINGS_CLIENT_ID`
  - `SMARTTHINGS_CLIENT_SECRET`
  - `SMARTTHINGS_REDIRECT_URI`

### Device Types Supported
- Locks
- Thermostats
- Lights
- Switches
- Generic Devices

### Rate Limiting
- 100 requests per minute per device
- 1000 requests per minute per user
- Automatic retry with exponential backoff

### Error Handling
- Authentication errors
- Network errors
- Rate limit errors
- Device-specific errors
- Validation errors

### Device Grouping
- Create and manage device groups
- Execute commands on multiple devices simultaneously
- Group devices by room or custom criteria
- Support for dynamic group membership

### Scene Support
- Create and manage scenes
- Execute scenes with multiple device actions
- Scene scheduling and automation
- Support for complex device interactions

### Next Steps
1. Comprehensive Error Handling
   - Detailed error codes
   - Recovery procedures
   - Error logging and monitoring

2. Test Coverage
   - Complete test suite for all device types
   - Edge case testing
   - Integration testing

3. Performance Optimization
   - Device state synchronization
   - Command execution optimization
   - Rate limiting improvements

## SmartThings Adapter

### Implementation Status
- ✅ Basic device operations
- ✅ Authentication
- ✅ Device discovery
- ✅ Command execution
- ✅ Webhook support
- ✅ Device grouping
- ✅ Scene support
- ✅ Error handling (with potential improvements needed)

### Error Handling
The current error handling implementation provides robust coverage for common scenarios, but there are areas that may need enhancement based on real-world usage:

#### Current Implementation
- Comprehensive error types and recovery procedures
- Retry mechanism with exponential backoff
- Structured logging and metrics collection
- Device-specific error handling

#### Future Improvements Needed
1. Device-specific recovery procedures:
   - Implement wake procedures for offline devices
   - Add device-specific reset procedures
   - Enhance state recovery mechanisms

2. Error context:
   - Add more detailed error context for debugging
   - Implement error aggregation for similar errors
   - Add error correlation across related operations

3. Monitoring:
   - Add error rate alerts
   - Implement error pattern detection
   - Add error impact analysis

These improvements will be prioritized based on real-world usage patterns and reported issues.

## August/Yale Lock Adapter

### Endpoints

August/Yale may differ in how they structure the API. Typically:
- **Login to get a session token**: `POST https://api.august.com/session`
- **Get Locks**: `GET https://api.august.com/locks`
- **Lock / Unlock**: `PUT https://api.august.com/locks/{lockId}/status`

### Lock State

- **States**: locked, unlocked, or possibly jammed.
- Handle extra fields like `battery_level`, `door_state` (open/closed).

### OAuth2 / Custom Auth

- Sometimes it's a custom authentication header (e.g., `X-August-Token`).
- Make sure to store tokens securely and refresh as needed.

---

## Philips Hue Adapter

### Endpoints

- Bridge-based local API (if on the same network) or Hue Remote API via the Philips developer portal.
- **Get Lights**:
  `GET https://api.meethue.com/v2/resource/light`
- **Set Light State**:
  `PUT https://api.meethue.com/v2/resource/light/{resourceId}`
  Body might include `{"on": {"on": true}, "dimming": {"brightness": 80}}`

### Additional Features

- **Color control**: `"color": {"xy": [0.3, 0.3]}` or other color model.
- **Scenes / Groups**: More advanced usage outside MVP scope.

## Handling OAuth2 Tokens

- **Token Storage**: Always use a secure store (Keychain on iOS).
- **Refresh Flow**:
  - On 401 response (invalid token), attempt a refresh with the refresh_token.
  - If refresh fails, prompt user to re-login.
- **Expiration**:
  - Some tokens expire in 3600 seconds (1 hour). Proactively refresh to avoid mid-operation failures.

## Error Handling & Retries

- **HTTP 400 / 404**: The request might be malformed or the device ID is invalid. Log the error and surface a user-friendly message ("Device not found").
- **HTTP 401**: Trigger token refresh; if it fails, re-prompt the user for credentials.
- **HTTP 429 (Rate Limit)**: Use an exponential backoff strategy. E.g., wait 1 second, 2 seconds, 4 seconds, etc., before retrying.
- **Network Timeouts**: Usually set a 10-15 second timeout for device commands. If the vendor is unresponsive, surface an error to the user.

## Vendor-Specific Tips

- **Nest**: Make sure your Google Cloud Project is properly configured with the Smart Device Management (SDM) scope.
- **SmartThings**: Capabilities can be dynamic, so robust parsing is essential.
- **August/Yale**: Watch for lock jam states and battery warnings.
- **Philips Hue**: Local IP-based connections can be faster but require the user's home network; the remote API might be better for rentals.