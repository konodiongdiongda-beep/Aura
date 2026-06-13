## Why

The Text Input screen is no longer part of the desired primary app experience. Keeping its bottom navigation entry exposes a debug-style page and leaves an unwanted selected marker in the tab bar.

## What Changes

- Remove the Text Input / keyboard page from the main bottom navigation.
- Prevent the bottom bar from rendering the keyboard tab or its selected visual marker.
- Keep History, Voice, and Settings as the only user-facing bottom navigation destinations.

## Capabilities

### New Capabilities
- `main-navigation`: Defines the user-facing bottom navigation destinations and excludes debug-only entry points.

### Modified Capabilities

## Impact

- Affected code: `AuraVoiceAssistant/App/ContentView.swift`
- Affected tests: iOS app unit tests for tab availability.
- No API, dependency, persistence, or backend changes.
