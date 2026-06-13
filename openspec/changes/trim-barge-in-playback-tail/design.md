## Context

The current behavior has two phases:

- Before barge-in: assistant playback is guarded and partial text is ignored.
- After verified barge-in: the coordinator enters interrupted recording so the user can speak.

The failing real-world case sits between these phases. The microphone and speech recognizer may still contain a short playback tail when the user begins speaking. The final transcript can therefore look like:

`<assistant words already spoken> + <actual user interruption>`

If the echo remover only rejects exact echo or leaves a mixed string intact, that mixed string can be sent as the next user turn.

## Decision

Store a snapshot of assistant playback text when interruption begins. For interrupted input, run a stricter cleanup before submission:

- Remove a leading assistant prefix if the final begins with assistant text.
- Remove common assistant text fragments from the beginning of the final.
- If the remaining text is empty or just filler, reject it as assistant echo.
- Submit only the remaining user text.

## Non-Goals

- Do not change enrollment or speaker-model behavior.
- Do not stop and restart Azure recognition for every playback segment in this change.
- Do not rely on this as the only echo-control layer.

## Risks

- Aggressive trimming could remove a short user phrase if it exactly repeats the assistant. The trade-off is acceptable during interrupted playback because replaying assistant output into the user turn is the more damaging failure.
