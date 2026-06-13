## 1. Tests

- [x] 1.1 Add regression coverage for playback partial suppression.
- [x] 1.2 Add regression coverage for verified voice-activity barge-in using audio evidence.
- [x] 1.3 Add regression coverage for unverified playback activity keeping playback active.
- [x] 1.4 Add rolling PCM empty snapshot coverage.
- [x] 1.5 Add first TTS segment latency coverage.

## 2. Implementation

- [x] 2.1 Add audio evidence to voice activity events.
- [x] 2.2 Use speaker evidence to allow playback-time barge-in.
- [x] 2.3 Suppress playback-time partial recognition as normal user input.
- [x] 2.4 Request Apple echo-cancelled input when available.
- [x] 2.5 Make rolling PCM snapshots safe.
- [x] 2.6 Lower first TTS segment threshold.

## 3. Validation

- [x] 3.1 Run targeted tests.
- [x] 3.2 Run `python3 -m unittest tools.speaker_verification.test_speaker_verification`.
- [x] 3.3 Run `swift test --package-path VoiceCore`.
- [x] 3.4 Run iOS workspace tests.
- [x] 3.5 Run `openspec validate implement-dual-mode-voice-barge-in --strict`.
- [x] 3.6 Launch the updated app in iPhone 17 Simulator.
