## Why

The app still sometimes feeds assistant playback back into the next user turn after a live barge-in. Text trimming helps when the assistant words are obvious in the transcript, but it does not clear Azure's existing audio and recognition buffer. When the user starts interrupting, the recognizer can still emit results from audio captured before playback cancellation.

## What Changes

- Reset the speech recognizer when a verified barge-in begins.
- Start a fresh recognition stream after the reset so stale events from the old stream cannot become the interrupted user turn.
- Keep the existing interrupted-input text cleanup as a second guard.

## Capabilities

### New Capabilities
- `barge-in-recognizer-reset`: Clear pre-barge-in speech recognition state when the user interrupts assistant playback.

### Modified Capabilities
- Voice coordinator recognition lifecycle during playback interruption.

## Impact

- Affected code: `VoiceCore` coordinator and tests; app recognizer already supports `cancel()` and `start()`.
- No new dependencies.
- Barge-in may lose a very small initial slice of speech while the recognizer restarts, but this is preferable to sending assistant playback back to the AI.
