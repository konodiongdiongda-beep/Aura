## Why

The offline prototype can enroll and score voice samples, but the call stack still needs a submission gate so STT output is not automatically sent to chat. This change wires a reusable gate into the backend prototype and `VoiceCore` before user turns are submitted.

## What Changes

- Add profile save/load and explicit normal/playback threshold modes to the speaker-verification prototype.
- Add a CLI gate command that returns accept/reject/uncertain behavior for one candidate file.
- Add `VoiceCore` user-turn submission gate contracts and default accept behavior.
- Inject the gate into `VoiceCallCoordinator` so recognized text can be blocked before `submitUserTurn` sends chat.
- Preserve current app behavior unless a stricter gate is explicitly injected.

## Capabilities

### New Capabilities
- `speaker-verification-turn-gate`: Runtime gate behavior for profile-backed user-turn acceptance before chat submission.

### Modified Capabilities
- `voice-turn-control`: User-turn submission gains a pre-submit rejection path.

## Impact

- Python speaker-verification prototype under `tools/speaker_verification/`.
- `VoiceCore` speech filtering contracts and coordinator tests.
- No production model or committed voice profile is added in this change.
