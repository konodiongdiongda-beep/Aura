## Context

`VoiceCallCoordinator` already accepts a `UserTurnSubmissionGating` dependency and evaluates it before chat submission. The app runtime does not pass a non-default gate, so real recognizer final events still go through `AcceptingUserTurnSubmissionGate`. This makes Simulator and Azure mode behave as if the earlier speaker-verification seam does not exist.

## Goals / Non-Goals

**Goals:**
- Ensure the App-created coordinator uses a real submission gate.
- Reject final recognition that occurs while assistant playback is active and is not an accepted interruption.
- Keep normal listening-mode user turns working.
- Keep shared policy types inside `VoiceCore` and app wiring inside `AuraVoiceAssistant`.

**Non-Goals:**
- Do not claim production-grade voice biometrics in this change.
- Do not add a full enrollment UI or on-device embedding extractor.
- Do not replace Azure Speech recognition or AVAudioSession behavior.

## Decisions

- Add a `PlaybackAwareUserTurnSubmissionGate` in `VoiceCore`.
  - Rationale: the rule is shared turn-control policy and should be testable without the app target.
  - Alternative considered: implement the check only in `VoiceCallViewModel`; rejected because it would bypass the existing coordinator seam and duplicate call-state policy.

- Add `submissionGate` to `SpeechServiceBundle`.
  - Rationale: `SpeechServiceFactory` is already the runtime selection point for mock/Azure/simulator speech behavior, so the coordinator can receive a coherent bundle.
  - Alternative considered: instantiate the gate directly in `VoiceCallViewModel`; rejected because tests need to assert factory wiring and future speaker-profile adapters belong beside speech runtime construction.

- Treat interrupted input as eligible while playback is active.
  - Rationale: current user barge-in must still work; the gate blocks playback echo finals, not verified interruptions already accepted by coordinator state.
  - Alternative considered: reject all playback-window final recognition; rejected because it would make barge-in impossible until the real speaker verifier is available.

## Risks / Trade-offs

- Playback echo that arrives after playback has fully drained can still rely only on text echo stripping until mic-audio speaker verification is wired. Mitigation: retain recent assistant echo text and keep the gate contract ready for the verifier adapter.
- Unknown real-user speech during playback requires the coordinator to mark interruption state before final submission. Mitigation: existing barge-in paths set `isCapturingInterruptedInput`; tests cover playback echo rejection without blocking normal speech.
