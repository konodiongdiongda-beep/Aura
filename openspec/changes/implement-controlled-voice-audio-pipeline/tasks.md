## 1. Shared VoiceCore Contracts

- [x] 1.1 Add failing tests for playback queue lifecycle events.
- [x] 1.2 Add failing coordinator tests for staying in speaking until playback drains.
- [x] 1.3 Extend shared speech playback and speaker verification contracts.

## 2. VoiceCore Implementation

- [x] 2.1 Implement event-emitting playback queue behavior.
- [x] 2.2 Wire coordinator playback-event handling and stream-completion state gating.
- [x] 2.3 Preserve existing barge-in, echo rejection, and simulator filter diagnostics.

## 3. App-Side Audio Implementation

- [x] 3.1 Add app-controlled synthesized-audio playback for Azure TTS.
- [x] 3.2 Update speech service factory to prefer controlled Azure playback when Azure mode is configured.
- [x] 3.3 Keep iOS voice-processing capture and playback-aware activity reporting compatible with simulator fallback.

## 4. Validation

- [x] 4.1 Run `swift test` in `VoiceCore`.
- [x] 4.2 Run OpenSpec validation for `implement-controlled-voice-audio-pipeline`.
- [x] 4.3 Run the iOS workspace test/build command and report any simulator/device limitations.
