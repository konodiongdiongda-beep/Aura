## 1. Tests

- [x] 1.1 Add regression coverage for interrupted final text with assistant prefix plus user speech.
- [x] 1.2 Add regression coverage for assistant-only interrupted final rejection.
- [x] 1.3 Verify normal listening final text is not trimmed.

## 2. Implementation

- [x] 2.1 Track assistant playback text at the moment barge-in starts.
- [x] 2.2 Trim assistant playback tail before submitting interrupted final recognition.
- [x] 2.3 Reject empty or filler-only results after trimming.

## 3. Validation

- [x] 3.1 Run targeted VoiceCore tests.
- [x] 3.2 Run `swift test --package-path VoiceCore`.
- [x] 3.3 Run iOS workspace tests.
- [x] 3.4 Run `openspec validate trim-barge-in-playback-tail --strict`.
- [x] 3.5 Launch the updated app in iPhone 17 Simulator.
