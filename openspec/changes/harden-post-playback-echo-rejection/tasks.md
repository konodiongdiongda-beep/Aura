## 1. Tests

- [x] 1.1 Add a regression test for post-playback assistant prompt recognition with punctuation/leading text removed.
- [x] 1.2 Add a regression test for distinct assistant display and voice text echo memory.

## 2. Implementation

- [x] 2.1 Preserve recent assistant echo variants in `VoiceCallCoordinator`.
- [x] 2.2 Reject post-playback final recognition that matches any recent assistant echo variant.

## 3. Verification

- [x] 3.1 Run focused `VoiceCallCoordinatorTests`.
- [x] 3.2 Run `swift test --package-path VoiceCore`.
- [x] 3.3 Run `openspec validate harden-post-playback-echo-rejection --strict`.
