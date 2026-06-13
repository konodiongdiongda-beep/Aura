## 1. Tests

- [x] 1.1 Add tests for reference PCM decode and append from TTS audio data.
- [x] 1.2 Add tests that microphone PCM is processed by the AEC component before Azure write/evidence.
- [x] 1.3 Add tests that empty reference data preserves microphone path.
- [x] 1.4 Add regression coverage for a live barge-in transcript that begins with assistant playback and continues with user speech.

## 2. Implementation

- [x] 2.1 Vendor `aec-rs` iOS headers/library and configure device build settings.
- [x] 2.2 Add acoustic echo canceller abstraction and shared reference bus.
- [x] 2.3 Feed decoded TTS PCM into the reference bus.
- [x] 2.4 Process microphone PCM through AEC before Azure push stream and evidence.
- [x] 2.5 Wire a shared AEC component through `SpeechServiceFactory`.
- [x] 2.6 Harden interrupted playback-prefix stripping for recognizer text where assistant and user speech are concatenated.

## 3. Validation

- [x] 3.1 Run targeted App tests.
- [x] 3.2 Run `swift test --package-path VoiceCore`.
- [x] 3.3 Run iOS workspace tests.
- [x] 3.4 Run `openspec validate integrate-reference-aec-for-ai-playback --strict`.
- [x] 3.5 Launch the updated app in iPhone 17 Simulator.
- [x] 3.6 Run focused `VoiceCallCoordinator` regression tests for barge-in echo stripping.
