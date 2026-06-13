## Why

The voice assistant still lacks an end-to-end runtime path that can prefer the enrolled user and reject AI playback or bystander speech before text reaches chat. Playback-aware text gating is necessary but insufficient; the app needs profile-backed audio evidence and deterministic replay tests so the behavior can be verified beyond subjective Simulator testing.

## What Changes

- Add a speaker-profile isolation contract that binds a final recognition candidate to recent microphone audio evidence.
- Add runtime gate policy that accepts verified current-user speech and rejects AI playback echo, other speakers, and uncertain speaker decisions.
- Add local enrollment/profile storage seams so the app can use a current-user profile within a single conversation and persist it for later sessions.
- Extend the offline replay prototype so user, AI playback, other-speaker, and mixed-audio scenarios produce pass/fail reports aligned with runtime gate decisions.
- Preserve the existing playback-aware gate as a conservative fallback when no profile or audio evidence is available.

## Capabilities

### New Capabilities
- `speaker-profile-runtime-isolation`: Profile-backed runtime voice isolation for AI playback echo and bystander rejection.

### Modified Capabilities

## Impact

- Affected code: `VoiceCore` speech filtering contracts, `VoiceCallCoordinator`, app Azure PCM input, app speech service factory, and speaker-verification tooling.
- No production ML model is bundled in this change; the runtime model adapter is designed to accept a future ONNX/CoreML embedding extractor.
- Validation requires unit tests, iOS workspace tests, OpenSpec validation, and deterministic recorded/mixed-audio reports.
