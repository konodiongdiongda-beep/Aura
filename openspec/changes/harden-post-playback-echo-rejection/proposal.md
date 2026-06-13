## Why

Assistant speech can still be recaptured by the microphone after playback drains and then submitted as a new user turn. The screenshot shows a user bubble that is effectively the previous Aura prompt without punctuation, which creates a self-triggered loop.

## What Changes

- Preserve recent assistant echo memory across display text and voice text, not only the last spoken variant.
- Reject post-playback recognition text that substantially matches recent assistant output before it reaches chat.
- Keep legitimate user barge-in and normal listening turns unchanged.

## Capabilities

### New Capabilities
- `post-playback-echo-rejection`: Reject assistant prompt text recognized shortly after playback as self-echo.

### Modified Capabilities

## Impact

- Affects `VoiceCallCoordinator` echo-memory and recognition filtering.
- Adds focused `VoiceCallCoordinatorTests` coverage.
- No backend API, persistence format, dependency, or UI layout change.
