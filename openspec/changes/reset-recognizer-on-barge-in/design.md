## Context

The current policy gates assistant playback and trims assistant text after interruption. The remaining failure is lower-level: Azure may have already buffered assistant playback audio before playback is cancelled. If that buffered result is emitted after barge-in starts, the coordinator may see it as interrupted input.

## Decision

When barge-in begins, the coordinator will reset recognition:

- Cancel the current recognizer session.
- Open a new event stream.
- Start recognition again.
- Ignore stale events from the previous stream by replacing the recognition task.

This is done only for playback/pending-response interruption, not normal listening.

## Non-Goals

- Do not stop recognition during every assistant playback segment.
- Do not remove speaker verification or text trimming.
- Do not change Azure SDK configuration in this change.

## Risks

- Restarting the recognizer during barge-in can cost a small amount of time.
- If restart fails, the coordinator should surface a speech recognition error instead of silently accepting stale input.
