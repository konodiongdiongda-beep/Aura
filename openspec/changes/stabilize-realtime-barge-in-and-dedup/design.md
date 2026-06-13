## Context

The app already has the right high-level architecture:

- iOS audio capture uses `playAndRecord`, `.voiceChat`, `setVoiceProcessingEnabled(true)`, and echo-cancelled input preference when available.
- Assistant TTS audio is captured as an AEC reference before playback.
- `VoiceCallCoordinator` owns state, barge-in, submission gating, stale stream handling, and text echo rejection.

The remaining issue is policy consistency. Recognition events from one spoken sentence can arrive as a short partial followed by a corrected final. If the partial has already been fast-submitted and the final is not a strict prefix/overlap match, the coordinator treats it as a second user turn. Separately, playback-mode barge-in must stay possible, but only after the signal is accepted as current-user speech.

## Goals / Non-Goals

**Goals:**
- One continuous spoken sentence produces at most one user message and one active chat submission; ASR revisions update or replace that turn.
- Playback-mode partial text is never submitted without accepted barge-in.
- Verified current-user activity can cancel assistant playback and allow the next user speech through.
- Assistant self-playback remains rejected during and shortly after playback.
- Preserve low-latency partial submission for genuine user speech.

**Non-Goals:**
- Replace Azure Speech or add a production speaker embedding model.
- Redesign the call UI.
- Remove the existing AEC/reference-capture stack.
- Server-side deduplication.

## Decisions

- Keep the fix in `VoiceCallCoordinator`. It is the shared layer that can see recognition timing, playback state, current user text, and chat submission state.
- Treat short CJK partials followed by longer highly similar finals as ASR revisions of the same sentence, even when the final inserts a repeated character or punctuation and does not strictly contain the partial.
- When correcting an already-submitted partial, update the existing user message in the transcript without opening another chat stream for the same spoken sentence.
- Run current-turn correction before creating a new listening/recognizing turn as well as while thinking. Azure can deliver the final result after a fast-submitted partial has already completed the assistant cycle or returned to listening.
- Superseded by `unify-duplex-barge-in-echo-and-latency`: keep audio evidence as the fastest path, but allow meaningful non-echo playback-window partials to trigger barge-in when speaker evidence is late or unavailable.
- Cache short-lived negative voice-activity decisions, so ASR partial/final text emitted from a just-rejected environment-noise or other-speaker window is discarded before the UI enters `recognizing`.
- Use AEC as an audio-layer mitigation and `SpeechEchoDetector` as a policy-layer fallback, matching common real-time voice designs such as platform voice processing, WebRTC-style AEC, and SpeexDSP-style far-end reference cancellation.
- Keep real-voice validation layered: recorded audio and Azure/device outputs are converted into trace JSON and reports outside `VoiceCore`; `VoiceCore` replays those traces deterministically without depending on Azure keys, microphones, or AVFoundation.
- Treat Simulator evidence as wiring/state validation only. Physical AEC, route leakage, Bluetooth/headset behavior, and device microphone pickup remain device-regression evidence.

## Risks / Trade-offs

- Aggressive revision merging could collapse a user intentionally repeating a phrase. Mitigation: only use the relaxed similarity rule while there is an active current turn being corrected before assistant response starts; non-overlapping follow-ups still submit as new turns.
- Some real-device barge-in quality still depends on route, microphone, and speaker volume. Mitigation: keep audio route/AEC enabled and block unverified playback audio from chat.
- Simulator cannot prove physical acoustic cancellation quality. Mitigation: verify coordinator policy with deterministic tests and build/launch the simulator; device acoustic tuning remains a runtime quality check.
- Trace fixtures can drift from the latest real acoustic behavior if they are not refreshed. Mitigation: each fixture records runtime route/AEC metadata and the report flags missing required metrics.
