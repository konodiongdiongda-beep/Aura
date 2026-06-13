## Context

The current coordinator rejects obvious assistant text echo and supports mock speaker hints, but final recognized text can still call `submitUserTurn` directly. The Python prototype can score WAV files but needs a loadable profile and gate output that maps to app decisions.

## Goals / Non-Goals

**Goals:**

- Make the prototype profile reusable through saved JSON.
- Support stricter playback-active verification thresholds.
- Add a `VoiceCore` pre-submit gate with tests proving rejected text is not sent to chat.
- Keep default app behavior unchanged until real speaker verification is injected.

**Non-Goals:**

- Build a production-grade iOS speaker embedding model.
- Stream raw audio into `VoiceCore` in this change.
- Replace existing text echo rejection.

## Decisions

- Python profile JSON stores the embedding so later backend-style tests can load it without re-enrolling.
- Playback mode uses a stricter accept threshold; `uncertain` is treated as not submittable during AI playback.
- `VoiceCore` gets a synchronous submission gate first because the coordinator currently handles recognition events synchronously on the main actor. A later production verifier can update the gate result from audio-level evidence.
- The default gate accepts all turns to preserve current simulator and app behavior.

## Risks / Trade-offs

- The first `VoiceCore` gate cannot verify raw audio by itself. It provides the blocking seam; audio evidence still needs to be fed from the app or backend verifier.
- Strict playback mode can reject valid short barge-ins if no verified speaker evidence is available. The app should display the rejection reason and continue listening.
