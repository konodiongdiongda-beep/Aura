## Why

Simulator testing still allows recognized assistant playback to re-enter the chat pipeline because the app runtime keeps using the default accept-all submission gate. The existing VoiceCore seam must be wired into the live app path so playback-window recognition is rejected before it can create a user turn.

## What Changes

- Carry a `UserTurnSubmissionGating` implementation through the app speech service bundle.
- Use a runtime gate that rejects final recognition while assistant playback is active unless the input is already marked as an interrupted user turn.
- Preserve normal user submission when the assistant is not playing.
- Add tests that prove the app-created coordinator rejects AI playback echo submissions and still accepts normal speech.

## Capabilities

### New Capabilities
- `runtime-playback-submission-gate`: Runtime wiring that prevents assistant playback recognition from being submitted as a user turn.

### Modified Capabilities

## Impact

- Affected code: `VoiceCore` submission gate implementations, `SpeechServiceFactory`, and `VoiceCallViewModel` coordinator construction.
- No new external dependency is introduced.
- This is a conservative runtime guard; production speaker-profile verification remains a later adapter behind the same gate contract.
