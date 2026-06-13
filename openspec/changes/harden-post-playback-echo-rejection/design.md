## Context

The coordinator already blocks many playback-window echoes and keeps playback active until drain. A remaining failure occurs when speech recognition emits assistant prompt text after playback has drained and the coordinator is back in listening mode. The current echo-memory path stores a single recent assistant text value and final handling records only `voiceText`, so alternate display/spoken variants can be lost.

## Goals / Non-Goals

**Goals:**
- Keep a recent assistant echo phrase set that includes both display and voice text.
- Use that recent echo memory to reject recognition text that matches the assistant prompt after playback drain.
- Preserve existing interruption and user-turn correction behavior.

**Non-Goals:**
- Replace Azure Speech recognition.
- Change the audio session, AEC library, or TTS playback implementation.
- Add a new UI surface.

## Decisions

- Store recent assistant echo text as a bounded list rather than one string. This keeps both final display and voice variants available without changing public APIs.
- Keep the rejection in `VoiceCallCoordinator` before chat submission. This is the shared, testable layer that already owns turn control and echo filtering.
- Reuse `SpeechEchoDetector` instead of introducing another similarity algorithm. The detector already normalizes punctuation and CJK text for assistant echo matching.

## Risks / Trade-offs

- Over-rejection of user speech that intentionally repeats the assistant prompt -> mitigated by requiring substantial similarity to recent assistant output and preserving the existing barge-in remainder handling for mixed speech.
- Echo memory growth -> mitigated by a small bounded recent-text list and the existing time window.
