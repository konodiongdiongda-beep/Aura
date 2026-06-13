## Why

History rows visually present a detail affordance, but users can fail to open the conversation detail from the visible card area. The app needs the entire displayed history row to behave as the detail entry point.

## What Changes

- Make every visible history row card a reliable tap target for opening its conversation detail.
- Preserve the existing local history loading, search filtering, and detail dismiss behavior.
- Add focused test coverage for the history-detail selection contract.

## Capabilities

### New Capabilities
- `history-detail-navigation`: Covers selecting a history row and opening the matching conversation detail.

### Modified Capabilities

## Impact

- Affected UI: `AuraVoiceAssistant/Views/History/HistoryListView.swift`
- Affected state/navigation: `AuraVoiceAssistant/App/ContentView.swift`
- Affected tests: `AuraVoiceAssistantTests`
