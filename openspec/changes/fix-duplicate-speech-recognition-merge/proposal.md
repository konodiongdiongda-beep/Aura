## Why

Live Azure speech recognition can emit multiple partial and final results for the same utterance, and those results may revise earlier words. The voice call coordinator currently submits partial text quickly and may later merge revised recognition text as a continuation, producing duplicated transcript content and duplicated chat submissions.

## What Changes

- Treat subsequent partial/final recognition text for the same in-flight utterance as a revision when it substantially overlaps the current user turn.
- Replace or merge overlapping recognition text without duplicating shared fragments.
- Preserve true follow-up speech while the assistant has not started responding.
- Add regression coverage for revised partial/final events that previously produced repeated transcript text.

## Capabilities

### New Capabilities
- `speech-recognition-turns`: Defines how live speech recognition partial and final events are normalized into user turns.

### Modified Capabilities

## Impact

- Affects `VoiceCallCoordinator` user turn merge behavior.
- Affects voice call transcript display and chat request payloads.
- No API, dependency, or data model changes.
