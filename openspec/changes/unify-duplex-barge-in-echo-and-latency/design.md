## Context

The app already has layered acoustic protection: platform voice processing/AEC in the app, assistant playback references, speaker evidence, and text echo rejection in `VoiceCore`. The weak point is orchestration. `VoiceCallCoordinator` currently returns immediately for partial recognition while `state == .speaking`, so a real user interruption can be ignored unless voice activity first arrives as verified current-user audio. In simulator/noisy/headset routes that evidence may be late or unavailable.

The response path also waits until backend stream text or final text arrives before queueing speech. If the backend has a slow first token or TTS has startup delay, the user hears a multi-second gap even though a local acknowledgement could safely play first.

## Goals / Non-Goals

**Goals:**
- Make playback-window barge-in work from either accepted audio evidence or meaningful non-echo ASR partial/final text.
- Keep assistant self-playback blocked before chat submission, including local prelude speech.
- Keep rejected background/other-speaker activity from holding the UI in `listening`/`recognizing`.
- Reduce perceived reply latency by queueing a short local prelude immediately after user-turn submission.
- Add deterministic closed-loop tests for interruption, echo rejection, and prelude cancellation.

**Non-Goals:**
- Replace Azure Speech, add a new cloud speaker model, or change backend ports.
- Claim simulator testing proves physical acoustic echo cancellation.
- Add UI controls or persistence changes.

## Decisions

- Use `VoiceCallCoordinator` as the single duplex policy owner. It already sees playback state, assistant echo memory, recognition text, voice activity, and chat submission.
- Evaluate assistant echo before barge-in. If playback-window ASR text is likely assistant output or an assistant tail, reject it and keep playback active.
- Allow meaningful non-echo partial text to start barge-in even without speaker evidence. This fixes the product requirement that the user can interrupt while the assistant is speaking, and it remains guarded by text echo rejection and minimum partial length.
- Keep audio evidence as the fastest path when it is clearly current-user speech. Unknown/noisy audio alone still waits for evidence or is rejected.
- Add a configurable local prelude text list to the coordinator. The prelude is enqueued after a user turn is accepted, remembered in assistant echo memory, and never appended as a chat message.
- Keep prelude short and cancelable. If the user interrupts the prelude, normal barge-in cancellation clears the playback queue and invalidates the active backend turn.

## Risks / Trade-offs

- Text-triggered barge-in can be too aggressive if ASR captures other people in a noisy room. Mitigation: preserve recent background rejection memory and echo-first filtering, and require a meaningful partial before interrupting.
- A local prelude can delay the first real assistant token if it is too long. Mitigation: keep the default phrase short and enqueue it before backend output only as a latency mask.
- Simulator validation does not prove device AEC or Bluetooth leakage quality. Mitigation: label simulator as wiring/state validation and keep real-voice trace coverage for repeatable coordinator behavior.
