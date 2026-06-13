## Why

The real-time voice loop still has two recurring failures:

- One spoken user sentence can appear as multiple user bubbles/chat submissions when Azure revises a short partial into a longer final result.
- Assistant playback and microphone capture must support real barge-in without letting Aura's own speaker output become a user turn.

Prior changes addressed these paths separately. The product needs one combined standard so deduplication, playback interruption, and assistant self-echo rejection are verified together.

## What Changes

- Define a single user-turn stability rule: a continuous spoken sentence may update the current pending/submitted user turn, but must not create an extra user message or chat submission for ASR revisions.
- Harden playback-mode input policy: assistant playback can be cancelled only for accepted current-user barge-in; assistant echo and unverified playback audio remain blocked.
- Keep audio output enabled while using the available AEC stack and text echo guard as layered protection.
- Add regression coverage for the screenshot-style duplicate partial/final sequence and verified playback interruption.
- Add a real-voice regression harness so recorded audio or Azure transcripts can be converted into deterministic coordinator trace tests and quality reports.

## Capabilities

### New Capabilities

- `realtime-voice-turn-control`: Stable user-turn deduplication plus verified playback barge-in and assistant echo rejection.

## Impact

- Affects `VoiceCallCoordinator` user-turn correction/deduplication and playback-mode recognition policy.
- May add focused app-level tests for audio session/speech-service wiring if needed.
- No backend API, persistence format, or UI layout change.
- Adds local test tooling under `tools/real_voice_regression/` and trace fixtures for `VoiceCore` tests.
