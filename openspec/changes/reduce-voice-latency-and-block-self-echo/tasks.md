## 1. Regression Coverage

- [x] 1.1 Add tests proving recognizer partial/final text is ignored while assistant playback is active.
- [x] 1.2 Keep or update tests proving explicit voice-activity interruption can still submit a user turn.
- [x] 1.3 Add tests proving non-echo recognizer speech interrupts playback.
- [x] 1.4 Add tests proving duplicated user recognition text is collapsed before submit.
- [x] 1.5 Add tests proving microphone voice activity interrupts playback before recognition text exists.

## 2. Core Implementation

- [x] 2.1 Add playback-aware recognition gating in `VoiceCallCoordinator`.
- [x] 2.2 Add lightweight turn latency markers/logging in `VoiceCallCoordinator`.
- [x] 2.3 Restore non-echo recognizer barge-in while preserving assistant echo rejection.
- [x] 2.4 Collapse repeated utterances before user turns are displayed and submitted.
- [x] 2.5 Use Azure Neural TTS for simulator Azure mode when credentials are configured.
- [x] 2.6 Emit microphone voice-activity events from Azure processed audio input.
- [x] 2.7 Cancel assistant playback immediately on voice activity and let later recognition text submit the turn.
- [x] 2.8 Make Azure TTS cancellation reachable while `speakText` is active.

## 3. Verification

- [x] 3.1 Run focused `VoiceCallCoordinatorTests`.
- [x] 3.2 Run the full Swift package test suite.
- [x] 3.3 Build and relaunch the iOS simulator app for manual testing.
- [x] 3.4 Re-run focused interruption tests.
- [x] 3.5 Rebuild and relaunch the simulator app after audio-activity interruption changes.
- [x] 3.6 Rebuild, test, and relaunch after Azure TTS cancellation fix.

## 4. Follow-up Regression Fixes

- [x] 4.1 Add a regression test proving voice activity cancels playback after chat stream completion while TTS may still be audible.
- [x] 4.2 Add a regression test proving short repeated Chinese user utterances are collapsed.
- [x] 4.3 Fix coordinator playback-tail barge-in gating and short duplicate utterance collapse.
- [x] 4.4 Run focused and full verification, rebuild, and relaunch the simulator app.

## 5. Remove Pending-Response Text Merge

- [x] 5.1 Add regression tests proving partial/final speech while assistant response is pending does not prepend the previous user turn.
- [x] 5.2 Add a regression test proving voice activity while assistant response is pending cancels the pending response before recognition text.
- [x] 5.3 Remove arbitrary pending-response continuation merging while preserving same-utterance ASR final corrections.
- [x] 5.4 Run focused and full verification, rebuild, and relaunch the simulator app.

## 6. Stabilize Interrupted Partial Submission

- [x] 6.1 Add a regression test proving incremental partial prefixes during pending-response interruption do not create multiple user messages.
- [x] 6.2 Add a regression test proving low-level voice activity during pending response does not show interruption captured.
- [x] 6.3 Use a longer stabilization window for interrupted partial input and tighten the immediate voice-activity barge-in threshold.
- [x] 6.4 Run focused and full verification, rebuild, and relaunch the simulator app.

## 7. Harden Barge-In Against Noise And Short Partials

- [x] 7.1 Add regression tests for short incremental partial prefixes, unknown short pending-response activity, and audio-only interruption recovery.
- [x] 7.2 Require stronger/sustained audio activity before audio-only barge-in, and avoid canceling pending responses for unconfirmed unknown activity.
- [x] 7.3 Suppress unstable short partial prefixes until final recognition text or a stable longer partial is available.
- [x] 7.4 Emit sustained voice-activity duration from Azure processed audio instead of per-buffer duration.
- [x] 7.5 Run focused and full verification, rebuild, and relaunch the simulator app.

## 8. Hold Short Chinese Lead-In Fragments

- [x] 8.1 Add a regression test proving short finalized lead-in fragments are not displayed as separate user messages.
- [x] 8.2 Buffer short discourse lead-ins and merge them into the following complete user turn.
- [x] 8.3 Run focused and full verification, rebuild, and relaunch the simulator app.
