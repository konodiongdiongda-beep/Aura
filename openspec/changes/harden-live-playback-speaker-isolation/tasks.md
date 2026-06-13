## 1. Tests

- [x] 1.1 Add VoiceCore regression coverage for unknown playback activity followed by assistant self-recognition.
- [x] 1.2 Add provider regression coverage proving playback-window audio is not enrolled.
- [x] 1.3 Add regression coverage that speaker verification rejection does not end the voice call.

## 2. Implementation

- [x] 2.1 Add context to speaker evidence requests so providers can distinguish safe enrollment from playback/interruption candidates.
- [x] 2.2 Harden adaptive enrollment policy to refuse playback-window enrollment.
- [x] 2.3 Harden coordinator barge-in policy so unknown VAD alone cannot promote assistant playback into user input.
- [x] 2.4 Keep rejection handling as a non-fatal filter result.

## 3. Validation

- [x] 3.1 Run targeted failing tests before implementation.
- [x] 3.2 Run `swift test --package-path VoiceCore`.
- [x] 3.3 Run iOS workspace tests.
- [x] 3.4 Run `openspec validate harden-live-playback-speaker-isolation --strict`.
- [x] 3.5 Launch the updated app in iPhone 17 Simulator.
