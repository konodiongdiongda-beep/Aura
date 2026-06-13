## 1. Regression Coverage

- [x] 1.1 Add a coordinator test for an auto-submitted partial followed by a revised overlapping final result.
- [x] 1.2 Add or preserve coverage for non-overlapping continuation speech while thinking.

## 2. Core Implementation

- [x] 2.1 Implement overlap-aware user recognition text merging in `VoiceCallCoordinator`.
- [x] 2.2 Route continuation and final merge paths through the overlap-aware merge helper.

## 3. Verification

- [x] 3.1 Run focused `VoiceCore` tests for voice call coordinator behavior.
- [x] 3.2 Run the broader `VoiceCore` test suite if the focused tests pass.
