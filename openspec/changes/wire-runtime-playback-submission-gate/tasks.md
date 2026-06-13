## 1. Runtime Gate

- [x] 1.1 Add a playback-aware user-turn submission gate implementation in `VoiceCore`.
- [x] 1.2 Add unit tests for playback echo rejection, normal acceptance, and interrupted input allowance.

## 2. App Wiring

- [x] 2.1 Add `submissionGate` to the app speech service bundle and factory output.
- [x] 2.2 Pass the bundled gate into `VoiceCallCoordinator` in the default ViewModel path.
- [x] 2.3 Add app tests proving factory-created coordinator wiring rejects playback-window self-echo.

## 3. Validation

- [x] 3.1 Run `swift test --package-path VoiceCore`.
- [x] 3.2 Run `xcodebuild test -workspace AuraVoiceAssistant.xcworkspace -scheme AuraVoiceAssistant -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath tmp/DerivedData`.
- [x] 3.3 Run `openspec validate wire-runtime-playback-submission-gate --strict`.
