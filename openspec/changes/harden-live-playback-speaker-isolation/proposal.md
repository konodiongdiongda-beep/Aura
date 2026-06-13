## Why

Live testing still shows the assistant's own spoken audio can enter the user input path. The current adaptive speaker provider can also treat the first available audio sample as current-user enrollment, which is unsafe when the assistant is speaking. When speaker verification rejects or cannot verify playback audio, the voice experience must remain in a usable call state instead of unexpectedly exiting.

## What Changes

- Prevent assistant playback windows from enrolling or accepting speaker evidence as the current user.
- Stop unknown energy-only microphone activity from immediately cancelling assistant playback before speaker evidence exists.
- Keep rejected playback, other-speaker, and uncertain speaker finals as non-fatal filtering outcomes.
- Add regression tests for assistant self-playback, playback-window enrollment, and rejection stability.

## Capabilities

### New Capabilities
- `live-playback-speaker-isolation`: Hardens runtime voice isolation for assistant playback and rejected speaker verification.

### Modified Capabilities

## Impact

- Affected code: `VoiceCore` coordinator/filtering and app speech evidence provider.
- No new third-party dependencies.
- This does not replace the prototype voiceprint algorithm with a production biometric model; it closes the live playback/enrollment policy holes around the existing provider.
