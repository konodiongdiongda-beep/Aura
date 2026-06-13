## Why

The backend debug service is running on port 6007 while the previous 8007 service is being debugged. The app should use 6007 by default for chat and history requests during this debugging window.

## What Changes

- Change the default chat WebSocket URL from port 8007 to 6007.
- Change the default history list and history messages URLs from port 8007 to 6007.
- Update local debug xcconfig defaults so simulator builds do not override the Swift defaults back to 8007.
- Preserve existing host, paths, request payloads, and environment override behavior.

## Impact

- Affects `VoiceCore/Sources/VoiceCore/Services/AppServices.swift`.
- Affects direct default client constructors in `ChatWebSocketClient` and `HistoryService`.
- Affects `AuraVoiceAssistant/App/AppConfig.swift` and local xcconfig defaults.
- Affects endpoint tests.
