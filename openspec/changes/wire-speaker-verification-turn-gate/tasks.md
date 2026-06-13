## 1. Backend Prototype Gate

- [x] 1.1 Add tests for profile save/load and strict playback gate output.
- [x] 1.2 Implement profile JSON loading and gate result serialization.
- [x] 1.3 Run gate reports against recorded user, AI playback, and mixed samples.

## 2. VoiceCore Submission Gate

- [x] 2.1 Add failing coordinator tests proving rejected turns are not submitted.
- [x] 2.2 Add shared submission gate contracts and default accept implementation.
- [x] 2.3 Wire `VoiceCallCoordinator` to evaluate the gate before chat submission.

## 3. Validation

- [x] 3.1 Run Python speaker-verification tests.
- [x] 3.2 Run `swift test` in `VoiceCore`.
- [x] 3.3 Run iOS workspace tests.
- [x] 3.4 Run OpenSpec validation for `wire-speaker-verification-turn-gate`.
