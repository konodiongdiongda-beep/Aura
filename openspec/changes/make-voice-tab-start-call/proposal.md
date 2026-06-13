## Why

The bottom navigation phone item currently starts a call as soon as users switch from History to Voice. Users expect this bottom item to navigate to the phone screen first, where the explicit call control starts the conversation.

## What Changes

- Make the center voice tab in the bottom navigation select the Voice screen without starting a call.
- Use phone-oriented iconography for the call entry affordances instead of microphone/recording iconography.
- Keep existing History and Settings navigation behavior unchanged.

## Capabilities

### New Capabilities
- `voice-call-entry`: Defines the voice call entry points and their expected tab navigation behavior.

### Modified Capabilities

## Impact

- Affected code: `AuraVoiceAssistant/App/ContentView.swift`, `AuraVoiceAssistant/Views/Voice/VoiceHomeView.swift`
- Affected tests: iOS app unit tests for bottom navigation and call entry behavior.
- No API, dependency, persistence, or backend changes.
