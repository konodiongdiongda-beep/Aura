## 1. Standards

- [x] 1.1 Add OpenSpec requirements for single-turn ASR revision handling.
- [x] 1.2 Add OpenSpec requirements for verified playback barge-in plus assistant self-echo rejection.

## 2. Tests

- [x] 2.1 Add a failing coordinator regression for screenshot-style Chinese partial/final revision duplication.
- [x] 2.2 Add/confirm coordinator regression for verified current-user barge-in cancelling playback while assistant echo remains blocked.
- [x] 2.3 Add a coordinator regression for delayed final revisions arriving after the state has returned to listening.
- [x] 2.4 Add coordinator regressions for environment-noise and other-speaker ASR text being rejected without holding `recognizing`.
- [x] 2.5 Add a screenshot-level regression for assistant tail echo returning while the coordinator is already thinking.

## 3. Implementation

- [x] 3.1 Harden current-turn correction so short CJK ASR revisions update the existing user turn instead of creating duplicate user bubbles.
- [x] 3.2 Keep playback-mode text and audio gates aligned with verified barge-in and assistant echo rejection.
- [x] 3.3 Apply current-turn correction before new-turn submission in listening/recognizing states.
- [x] 3.4 Add short-lived background-activity suppression before partial/final user-turn handling.
- [x] 3.5 Harden recent assistant-tail echo rejection across thinking/listening and headphone routes.

## 4. Verification

- [x] 4.1 Run focused failing-then-passing `VoiceCallCoordinatorTests`.
- [x] 4.2 Run full `swift test --package-path VoiceCore`.
- [x] 4.3 Run `openspec validate stabilize-realtime-barge-in-and-dedup --strict`.
- [x] 4.4 Build, install, and launch `AuraVoiceAssistant.xcworkspace` on iOS Simulator.

## 5. Real Voice Regression MVP

- [x] 5.1 Add OpenSpec requirements for replayable real-voice trace/report validation.
- [x] 5.2 Add real-voice regression manifest, trace fixtures, and report tooling under `tools/real_voice_regression/`.
- [x] 5.3 Add `VoiceCore` trace replay tests that validate assistant echo rejection and short-answer acceptance.
- [x] 5.4 Add local Python validation for manifest/report schema and fixture pass/fail output.
- [x] 5.5 Run focused trace tests, Python tests, full `VoiceCore` tests, and strict OpenSpec validation.
