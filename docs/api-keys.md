# Unified Smart Home – API & Secret Reference

This document lists every external credential the project consumes and how each layer (backend or iOS app) expects to receive it.

| Key / Secret | Consumed By | Source (Prod) | Local Dev Injection | Notes |
|--------------|-------------|---------------|---------------------|-------|
| `MONGODB_URI` | Backend (`backend/config/db.js`) | Render **Environment Group – Production** | `.env` or `backend/env.example` | Atlas SRV string incl. DB name.
| `JWT_SECRET` | Backend Auth (`routes/auth.js`) | Render env | `.env` | 32+ random chars.
| `ALLOWED_ORIGINS` | Backend CORS (`server.js`) | Render env | `.env` | Comma-separated list.
| `DATADOG_API_KEY` | Backend logging (`logger.js`) | Render env | Optional | Enables Pino-Datadog transport.
| `SMARTTHINGS_API_KEY` | iOS SmartThingsAdapter | Xcode `.xcconfig` loaded in Fastlane lane | `.xcconfig.local` or scheme env | |
| `SMARTTHINGS_CLIENT_ID` | iOS SmartThingsTokenManager | same as above | same | |
| `SMARTTHINGS_CLIENT_SECRET` | iOS SmartThingsTokenManager | same | same | |
| `YALE_API_KEY` | iOS YaleLockAdapter | same | same | |
| `YALE_CLIENT_ID` | iOS YaleLockAdapter | same | same | |
| `YALE_CLIENT_SECRET` | iOS YaleLockAdapter | same | same | |
| `AUGUST_API_KEY` | iOS AugustLockAdapter (`Sources/Models/AugustConfiguration.swift`) | hard-coded constant for now → **move to xcconfig before launch** | replace placeholder | |
| `NEST_CLIENT_ID` | iOS Info.plist | Info.plist (Prod config) | Info.plist dev placeholder | |
| `NEST_CLIENT_SECRET` | iOS Info.plist | Info.plist | |
| `NEST_PROJECT_ID` | iOS Info.plist | Info.plist | |
| `HUE_APPLICATION_KEY` | iOS HueLightAdapter | xcconfig | same | Generated during Hue Bridge pairing.
| `FASTLANE_SESSION` | Fastlane (`Fastfile`) | GitHub Actions secret & local shell | `.env.local` | 30-day session token.
| `MATCH_PASSWORD` | Fastlane `match` (optional) | GitHub Actions secret | `.env.local` | Only if you enable `match`.
| `RENDER_DEPLOY_HOOK` | GitHub Actions backend deploy workflow | GitHub Actions secret | N/A | URL from Render.

## Injecting Keys in Xcode Builds

We recommend using a pair of **xcconfig** files:

```
ios/config/Prod.xcconfig     # committed, no secrets (uses $(VAR) tokens)
ios/config/Prod.secrets.xcconfig  # NOT committed, filled in by CI
```

In Xcode → Project → Info, set **Configuration** → Release to include both files (the second as ‘based on’). Fastlane can generate the secrets file during the `build` lane:

```ruby
before_all do
  secrets = <<~EOS
  SMARTTHINGS_API_KEY=#{ENV["SMARTTHINGS_API_KEY"]}
  YALE_API_KEY=#{ENV["YALE_API_KEY"]}
  # …others…
  EOS
  File.write("config/Prod.secrets.xcconfig", secrets)
end
```

Local developers should copy `ios/config/Dev.example.xcconfig` → `Dev.secrets.xcconfig` and fill in their own tokens.

---

Feel free to update this file whenever new integrations are added or credential paths change. 