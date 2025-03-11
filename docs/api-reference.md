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

### Endpoints

- **Get Devices**: `GET https://api.smartthings.com/v1/devices`
- **Device Details**: `GET https://api.smartthings.com/v1/devices/{deviceId}/status`
- **Command**: `POST https://api.smartthings.com/v1/devices/{deviceId}/commands` with body:
  ```json
  {
    "commands": [
      {
        "component": "main",
        "capability": "switch",
        "command": "on"
      }
    ]
  }

### Specifics

- Each device can have multiple capabilities (e.g., switch, temperatureMeasurement, lock, etc.).
- The adapter must parse capability sets to determine which DeviceType they map to.

### OAuth2 Setup

- **Personal Access Token or OAuth2**:
  - SmartThings may use a personal access token approach in developer mode.
  - For production, standard OAuth2 is recommended.

---

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