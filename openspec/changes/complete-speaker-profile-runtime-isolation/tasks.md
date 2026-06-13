## 1. Research And Architecture

- [x] 1.1 Document practical speaker-verification/AEC options and choose the repo-compatible adapter path.
- [x] 1.2 Define runtime evidence, profile, and decision contracts in `VoiceCore`.

## 2. Runtime Gate

- [x] 2.1 Extend `UserTurnSubmissionCandidate` with speaker evidence while preserving existing callers.
- [x] 2.2 Implement strict profile-aware submission gate with playback and normal-listening thresholds.
- [x] 2.3 Update `VoiceCallCoordinator` tests for verified user, AI playback, bystander, uncertain, and mixed interruption cases.

## 3. App Audio Evidence

- [x] 3.1 Add rolling PCM capture/evidence extraction to app-owned Azure audio input.
- [x] 3.2 Add app-side speaker evidence provider seam to Azure recognition finals.
- [x] 3.3 Preserve conservative fallback when profile or audio evidence is missing.

## 4. Replay Verification

- [x] 4.1 Extend the Python verifier fixtures/reports to include an other-speaker surrogate and strict runtime gate output.
- [x] 4.2 Run replay reports for user, AI playback, other speaker, and mixed audio and store generated reports under `tmp/`.

## 5. Validation

- [x] 5.1 Run Python speaker-verification tests.
- [x] 5.2 Run `swift test --package-path VoiceCore`.
- [x] 5.3 Run iOS workspace tests.
- [x] 5.4 Run `openspec validate complete-speaker-profile-runtime-isolation --strict`.
- [x] 5.5 Launch the updated app in iPhone 17 Simulator for manual retest.
