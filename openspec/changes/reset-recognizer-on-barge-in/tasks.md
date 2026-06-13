## 1. Tests

- [x] 1.1 Add coverage that verified barge-in cancels and restarts recognition.
- [x] 1.2 Add coverage that stale old-stream assistant text after reset is ignored.
- [x] 1.3 Add coverage that fresh post-reset user speech is still submitted.

## 2. Implementation

- [x] 2.1 Add coordinator recognizer reset on barge-in start.
- [x] 2.2 Ensure stale recognition tasks cannot process old-stream events after reset.
- [x] 2.3 Surface restart failures as speech recognition errors.

## 3. Validation

- [x] 3.1 Run targeted VoiceCore tests.
- [x] 3.2 Run `swift test --package-path VoiceCore`.
- [x] 3.3 Run iOS workspace tests.
- [x] 3.4 Run `openspec validate reset-recognizer-on-barge-in --strict`.
- [x] 3.5 Launch the updated app in iPhone 17 Simulator.
