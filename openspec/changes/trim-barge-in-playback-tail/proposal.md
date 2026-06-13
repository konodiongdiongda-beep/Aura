## Why

The dual-mode barge-in policy prevents assistant playback partials from becoming user input. A remaining live issue appears after a verified user barge-in starts: Azure may return a final transcript that still includes assistant speech captured just before playback cancellation, followed by the user's interruption. That mixed final can feed the assistant's own words back into the next user turn.

## What Changes

- Track the assistant text that was audible at the moment barge-in starts.
- When interrupted recognition produces final text, remove assistant playback text from the mixed transcript before submission.
- Reject the final if removing playback text leaves no meaningful user speech.
- Preserve normal listening behavior and verified user barge-in behavior.

## Capabilities

### New Capabilities
- `barge-in-tail-trimming`: Prevent assistant playback tail audio from being submitted with the user's interrupted turn.

### Modified Capabilities
- Voice coordinator interrupted-input cleanup and echo stripping.

## Impact

- Affected code: `VoiceCore` coordinator and tests.
- No new dependency.
- This complements Apple echo cancellation and speaker checks; it handles the recognizer's final text after a real user barge-in.
