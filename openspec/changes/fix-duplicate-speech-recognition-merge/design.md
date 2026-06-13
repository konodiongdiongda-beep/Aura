## Context

Azure continuous recognition emits interim partial text and later final text for an utterance. Interim text is not stable: later events can repeat, extend, or revise earlier words. The coordinator currently auto-submits partial text quickly, then treats additional recognition while the assistant has not produced output as a user continuation. That is valid for genuine follow-up speech, but it duplicates content when the later event is a revised version of the same utterance.

## Goals / Non-Goals

**Goals:**
- Keep the fast partial-submit behavior for low-latency voice calls.
- Deduplicate overlapping partial/final events from the same spoken turn.
- Keep support for genuine additional speech while the assistant is still thinking.
- Cover the behavior with focused coordinator tests.

**Non-Goals:**
- Change Azure SDK configuration, microphone capture, audio routing, or echo cancellation.
- Add server-side deduplication.
- Change transcript UI layout.

## Decisions

- Add a coordinator-level text merge helper for user recognition text. It will prefer the most complete overlapping text when two strings share a prefix/suffix or one contains the other, and will only append with a space when there is no meaningful overlap.
  - Alternative: wait only for final recognition. Rejected because it increases voice response latency and removes the existing fast partial-submit behavior.
  - Alternative: ignore all recognition while thinking. Rejected because the app already supports users adding context before the assistant starts responding.
- Keep the merge local to `VoiceCallCoordinator` because the bug is caused by user-turn state transitions, not by Azure event delivery itself.
  - Alternative: normalize inside `AzureSpeechRecognizer`. Rejected because the recognizer should remain a thin event adapter and does not know whether a later event belongs to a new turn or a current chat submission.

## Risks / Trade-offs

- Overlap matching could merge two intentionally repeated phrases → Mitigation: only collapse when the overlap is long enough to indicate a recognition revision, while exact prefix/containment remains deterministic.
- Very noisy recognition can still emit nonsensical text → Mitigation: this change prevents app-level duplication but does not claim to improve speech recognition quality.
