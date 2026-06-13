## 1. History Detail Selection

- [x] 1.1 Add focused coverage for selecting a history conversation from the list.
- [x] 1.2 Make each visible history row card a full-width tappable detail target.
- [x] 1.3 Preserve existing detail overlay dismissal behavior.
- [x] 1.4 Prevent shared glass panel decoration from intercepting history row taps.

## 2. Verification

- [x] 2.1 Run the relevant iOS unit tests or document why they cannot run.
- [x] 2.2 Validate the OpenSpec change status.

## Verification Notes

- `xcodebuild test -workspace AuraVoiceAssistant.xcworkspace -scheme AuraVoiceAssistant -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:AuraVoiceAssistantTests/HistoryListViewModelTests` passed 7 tests.
- `xcodebuild test -workspace AuraVoiceAssistant.xcworkspace -scheme AuraVoiceAssistant -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:AuraVoiceAssistantTests/HistoryListViewModelTests/testGlassPanelDecorativeOverlayDoesNotBlockRowSelection` failed before the fix, then passed after disabling hit testing on the decorative overlay.
- `xcodebuild test -workspace AuraVoiceAssistant.xcworkspace -scheme AuraVoiceAssistant -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:AuraVoiceAssistantTests` passed 32 tests.
