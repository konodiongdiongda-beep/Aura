## 1. Standards

- [x] 1.1 Add OpenSpec proposal, design, and requirements for unified duplex turn control.
- [x] 1.2 Keep the documented live backend endpoint on port `6007`.

## 2. Tests

- [x] 2.1 Add a failing coordinator regression for non-echo partial text interrupting assistant playback.
- [x] 2.2 Add a coordinator regression proving assistant partial echo still does not interrupt or submit.
- [x] 2.3 Add a coordinator regression for local prelude enqueue, echo memory, and no chat-message pollution.
- [x] 2.4 Add a coordinator regression proving a user can interrupt the local prelude.
- [x] 2.5 Add a coordinator regression proving local prelude playback does not mask backend response timeout.
- [ ] 2.6 Add a coordinator regression proving ASR partial/final revisions after fast submit update one user bubble.

## 3. Implementation

- [x] 3.1 Replace the playback partial early-return with echo-first text barge-in classification.
- [x] 3.2 Add configurable local prelude playback to accepted user-turn submission.
- [x] 3.3 Ensure local prelude speech is remembered for echo rejection and is cancelable through the normal barge-in path.
- [x] 3.4 Preserve background rejection, assistant echo rejection, and duplicate-turn correction behavior.
- [x] 3.5 Keep local prelude playback separate from real assistant response state and watchdog completion.
- [ ] 3.6 Route same-utterance partial revisions while thinking through current-turn correction before starting a new interruption.

## 4. Verification

- [x] 4.1 Run focused failing-then-passing `VoiceCallCoordinatorTests`.
- [x] 4.2 Run full `swift test --package-path VoiceCore`.
- [x] 4.3 Run real-voice regression report tooling.
- [x] 4.4 Run strict OpenSpec validation.
- [x] 4.5 Build/install/launch the iOS Simulator app and confirm it uses port `6007`.
- [x] 4.6 Run real-voice regression, strict OpenSpec validation, and rebuild/relaunch simulator after the local prelude timeout fix.
- [ ] 4.7 Run focused ASR revision regressions, full `VoiceCore` tests, app tests, and strict OpenSpec validation.
