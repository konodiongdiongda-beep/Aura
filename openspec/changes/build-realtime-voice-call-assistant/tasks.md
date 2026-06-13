## 1. Project and Configuration

- [x] 1.1 Create a native SwiftUI iOS project structure under the workspace with app entry point, asset catalog, and test targets.
- [x] 1.2 Add shared app-domain models, service protocols, and view-model contracts from `phase-1-2-shared-standards.md` before implementing Phase 1 or Phase 2 feature code.
- [x] 1.3 Set all iOS deployment targets and Swift package platform declarations to iOS 15.0 minimum and avoid iOS 16+ APIs unless guarded by availability fallbacks.
- [x] 1.4 Add Microsoft Azure Speech SDK dependency and verify it builds for a physical iOS device target.
- [x] 1.5 Add `AppConfig` loading for chat endpoints, history endpoints, Azure Speech key, Azure Speech region, preferred voice name, default `test01` user, and `user_id` 35.
- [x] 1.6 Add microphone and speech-related usage descriptions to the app plist.
- [x] 1.7 Add a secret-safe sample config file that documents required Azure Speech values without committing real keys.
- [x] 1.8 Wire app build configurations to optional local xcconfig files so Simulator runs can use real Azure Speech credentials without committing secrets.

## 2. Design System and Screens

- [x] 2.1 Implement SwiftUI color, typography, spacing, and glass-panel primitives from `stitch_aura_ai_voice_assistant.zip`.
- [x] 2.2 Implement the idle voice home screen with assistant header, central voice control, start-call action, and bottom navigation.
- [x] 2.3 Implement the in-call screen with timer, waveform, transcript area, mute/end/speaker controls, and state labels.
- [x] 2.4 Implement settings/configuration screen showing Azure Speech readiness, user identity, speaker enrollment, and microphone status.
- [x] 2.5 Implement history list and message detail screens matching the visual direction of the provided history reference.
- [x] 2.6 Implement an in-app English/Chinese language switch for settings, navigation, and primary Phase 1 UI labels.
- [x] 2.7 Keep the in-call transcript scrollable within the available height so existing messages do not push call controls or bottom navigation off-screen.
- [x] 2.8 Persist call transcript text locally and make History list/detail read local conversations instead of runtime mock data.
- [x] 2.9 Remove the idle top assistant header from the in-call screen and keep the transcript scrolled to the latest conversation by default.
- [x] 2.10 Make the bottom navigation bar more compact while preserving safe-area spacing.
- [x] 2.11 Use the supplied Aura microphone artwork as the iOS app icon asset.
- [x] 2.12 Make top header surfaces extend into the iOS status area and keep the bottom navigation flush/compact at the screen edge.
- [x] 2.13 Keep the in-call timer below the top safe-area/Dynamic Island region on modern iPhone devices.

## 3. Chat Integration

- [x] 3.1 Implement `ConversationIDFactory` for `cid`, `cid_md5`, `second_time`, `request_id`, `user_chat_id`, and `bot_chat_id`.
- [x] 3.2 Implement typed request models for the documented WebSocket chat payload.
- [x] 3.3 Implement `ChatWebSocketClient` using `URLSessionWebSocketTask`.
- [x] 3.4 Implement `ChatStreamParser` for `final_token`, `model_response`, `tool_execution`, `message_ids`, and `finish` events.
- [x] 3.5 Add unit tests for request metadata generation and stream parsing, including mixed `display_text` and `text` fragments.

## 4. Azure Speech and Audio

- [x] 4.1 Implement `AudioSessionManager` using play-and-record voice-call settings, speaker output, Bluetooth support, and lifecycle cleanup.
- [x] 4.2 Implement `AzureSpeechRecognizer` for continuous recognition with partial and final transcript callbacks.
- [x] 4.3 Implement `AzureSpeechSynthesizer` for text-to-speech synthesis with cancellation support.
- [x] 4.4 Implement `TTSPlaybackQueue` that speaks complete sentence chunks and flushes remaining text on final completion.
- [x] 4.5 Add error handling for missing Azure key/region, microphone denial, recognition failure, and synthesis failure.
- [x] 4.6 Add `SpeechServiceFactory` simulator fallback so missing Azure config uses mock STT/TTS and Settings reports current speech mode/environment.
- [x] 4.7 Add a simulator debug entry that emits a mock `SpeechRecognitionEvent.final(...)` for Phase 4 coordinator integration.

## 5. Call State Machine and Interruption

- [x] 5.1 Implement `VoiceCallCoordinator` as the single owner of call state, active transcript, current turn IDs, and service orchestration.
- [x] 5.2 Wire start-call to configure audio, start recognition, create a conversation ID, and update UI state.
- [x] 5.3 Wire final user recognition to send chat text, stream AI text, segment TTS, and play synthesized audio.
- [x] 5.4 Implement barge-in from `speaking` state that stops playback, clears queued TTS, cancels or ignores stale chat streams, and starts a new user turn.
- [x] 5.5 Add unit tests for state transitions: idle-to-listening, listening-to-thinking, thinking-to-speaking, speaking-to-interrupted, and end-call cleanup.

## 6. Noise, Echo, and Speaker Filtering

- [ ] 6.1 Implement local voice activity detection based on input level and sustained speech duration.
- [ ] 6.2 Gate barge-in triggers through VAD thresholds to avoid ambient noise interruptions.
- [ ] 6.3 Add audio capture buffering for optional speaker verification snippets.
- [ ] 6.4 Implement speaker enrollment flow and local storage of speaker profile reference.
- [ ] 6.5 Implement speaker verification before chat submission when enough audio is available, with clear UI handling for failed or unavailable verification.

## 7. History APIs

- [x] 7.1 Implement `HistoryService` for `history/user/page`.
- [x] 7.2 Implement message-list loading for `history-with-alerts/`.
- [x] 7.3 Map backend history/message responses into Swift models used by the history UI.
- [ ] 7.4 Add refresh, pagination basics, search filtering, loading state, and error state.

## 8. Verification and Delivery

- [x] 8.1 Run unit tests for metadata, parser, state machine, and history mapping.
- [ ] 8.2 Run the app on a physical iPhone and verify microphone permission, recognition, synthesis, speaker output, and end-call cleanup.
- [ ] 8.3 Verify AI playback can be interrupted by user speech and stale AI audio/text does not resume.
- [ ] 8.4 Test noisy room and second-speaker scenarios and tune VAD/speaker-verification thresholds.
- [x] 8.5 Document setup steps, Azure Speech configuration, known limitations, and true-device test results.
- [x] 8.6 Verify simulator mock speech path and Azure SDK initialization build path through `AuraVoiceAssistant.xcworkspace`.
- [ ] 8.7 Verify one real simulator voice conversation using Mac microphone, Azure Speech mode, and live chat WebSocket.
- [x] 8.8 Remove simulator/debug controls from the visible call screen before real-user testing.
- [x] 8.9 Keep runtime speech/chat errors visible in the in-call screen instead of returning to the idle home screen.
- [x] 8.10 Add Azure Speech recognition diagnostics and use a simulator-friendly audio session mode for the real voice smoke test.
- [x] 8.11 Add live WebSocket diagnostics for the real voice smoke test after Azure STT submits recognized speech.
- [x] 8.12 Allow the provided cleartext chat and history endpoints through ATS for local Simulator testing.
- [x] 8.13 Stabilize the real simulator voice smoke test by ignoring extra STT final events while a chat turn is already thinking and treating locally canceled WebSocket streams as normal stale-turn cleanup.
- [x] 8.14 Remove remaining visible mock/Phase 1 preview labels from primary user-facing screens before real Simulator testing.
- [x] 8.15 Filter streamed JSON/final-result fragments out of visible transcript and TTS so metadata such as `intent`/`chat` is never spoken.
- [x] 8.16 Prevent duplicate TTS playback by speaking streamed assistant text once and using the finish event only to finalize transcript state.
- [x] 8.17 Make TTS chunking more conversational by avoiding short comma/list-punctuation segments while still flushing final text.
- [x] 8.18 Add regression coverage that multiple voice turns in the same call reuse one conversation `cid` for backend memory.
- [x] 8.19 Reduce user-silence-to-request latency by configuring Azure Speech continuous recognition with a shorter time-based end-silence segmentation timeout for call mode.
- [x] 8.20 Reduce text-to-speech start latency by emitting a short first TTS chunk as soon as enough streamed text arrives, then continuing with natural sentence/length chunks.
- [x] 8.21 Reuse the Azure speech synthesizer across TTS chunks during a call to avoid per-segment connection setup overhead.
- [x] 8.22 Submit stable partial recognition after a sub-second pause so the chat request does not wait for Azure final segmentation in fast-call mode.
- [x] 8.23 Lower Azure Speech end-silence segmentation for the simulator smoke-test path while preserving continuous recognition.
- [x] 8.24 Add a low-latency local iOS TTS synthesizer for Simulator real-call testing to avoid cloud synthesis startup delay.
- [x] 8.25 Cover fast partial submission and low-latency TTS selection with regression tests.
- [x] 8.26 Make live STT partial/final events immediately stop assistant playback while speaking before any VAD or speaker-verification gate.
- [x] 8.27 Keep the call in user-listening/recognizing state after an immediate voice interruption until the user's final utterance is submitted.
- [x] 8.28 Add regression coverage for immediate foreground barge-in from partial and final STT events.
- [x] 8.29 Sanitize TTS playback text so punctuation and symbols are not spoken aloud while preserving natural chunking.
- [x] 8.30 While waiting for the first assistant token, merge continued user speech into the current user turn, cancel the stale pending chat stream, and resend the combined question.
- [x] 8.31 Add regression coverage for punctuation-free TTS playback and thinking-state user continuation.
- [x] 8.32 Reject STT partial/final events during assistant playback when the recognized text is likely an echo of the current assistant utterance.
- [x] 8.33 Prefer voice-chat audio session processing in Simulator for the real call path to reduce speaker-to-microphone echo where supported.
- [x] 8.34 Add regression coverage that assistant echo does not interrupt playback or submit a new user turn.
- [x] 8.35 Slow the local Simulator TTS speaking rate to a more natural call pace.
- [x] 8.36 Reduce the fast partial auto-submit delay and Azure end-silence timeout further for lower perceived recognition latency.
- [x] 8.37 Fix multi-step user continuation so repeated speech before the first assistant token is appended to the existing user turn instead of replacing it.
- [x] 8.38 Add regression coverage for repeated thinking-state continuations and true user interruption after echo filtering.
- [x] 8.39 Keep recent assistant speech available for echo rejection after the chat stream completes while local TTS may still be audible.
- [x] 8.40 Add regression coverage for post-completion assistant echo rejection without rejecting short user answers to assistant prompts.
- [x] 8.41 Lower client-side fast partial submit and Azure end-silence thresholds for the fastest practical simulator voice path.
- [x] 8.42 Ignore duplicate Azure final recognition when the same text was already submitted from a stable partial, while still resending extended final text.
- [x] 8.43 Add regression coverage for duplicate-final suppression and extended-final resend behavior.
- [x] 8.44 Preserve assistant echo memory across the user's fast partial submission so Azure final events cannot append speaker echo into the user turn.
- [x] 8.45 Strip assistant echo tails from mixed user-plus-echo recognition results while preserving the user's real prefix.
- [x] 8.46 Add regression coverage for mixed user speech plus assistant echo and for longer valid user answers that share terms with the assistant prompt.
- [x] 8.47 Route Azure STT through an app-owned processed microphone PCM stream instead of the Azure SDK default microphone.
- [x] 8.48 Enable iOS voice-processing capture on the app-owned microphone stream where supported and log the active STT input path.
- [x] 8.49 Verify the processed microphone stream builds and keeps existing voice-call regression tests passing.
