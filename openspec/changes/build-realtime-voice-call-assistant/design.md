## Context

The workspace currently contains API documentation in `对话接口.txt` and a visual reference package `stitch_aura_ai_voice_assistant.zip`. There is no existing iOS project and no Azure Speech subscription key or region in the project files. The backend chat API streams JSON events over WebSocket, while Azure Speech must handle local microphone recognition and speech synthesis on the device.

The product target is a native iOS source-code delivery, not App Store distribution. The app can therefore use local configuration for credentials and can prioritize true-device behavior over App Store review constraints.

The minimum supported OS version is iOS 15. Implementation must avoid iOS 16+ only APIs or wrap them in availability checks with iOS 15 fallbacks.

## Goals / Non-Goals

**Goals:**

- Build a native SwiftUI iOS app with an Aura/Doubao-like voice-call page and visible live transcript.
- Support continuous spoken turns using Azure Speech recognition and synthesis.
- Support user barge-in while the AI is speaking.
- Stream AI response text to the screen while preparing sentence-level TTS playback.
- Reduce noise, echo, and other-speaker input before sending user utterances to chat.
- Keep chat request metadata compatible with the provided interface contract.
- Provide history and message-list pages for debugging and conversation review.

**Non-Goals:**

- App Store submission, account/login infrastructure, payment, push notification, or backend changes.
- A guarantee that all non-user voices are rejected in every acoustic condition.
- A custom low-level neural noise suppression model unless built-in iOS/Azure filtering proves insufficient.
- Offline speech recognition or offline TTS.

## Decisions

### Decision -1: Simulator can run a real Azure/chat path when explicitly configured

The simulator path is allowed to use real Azure Speech STT/TTS with the Mac microphone/speaker when `AZURE_SPEECH_MODE=azure` and Azure key/region are present. Simulator audio remains insufficient for final acoustic validation, but it is a valid development path for one real spoken chat turn through Azure Speech and the live chat WebSocket.

Local Simulator runs should load those values from an uncommitted `AuraVoiceAssistant/App/LocalConfig.xcconfig` via checked-in Debug/Release xcconfig wrappers. The wrapper files must include the CocoaPods generated xcconfig first and then include `LocalConfig.xcconfig` optionally, preserving both pod linkage and local secret injection.

### Decision 0: Share app-domain contracts between Phase 1 and Phase 2

Phase 1 UI and Phase 2 chat/history services will be developed in parallel against shared app-domain models, service protocols, and view-model shapes documented in `phase-1-2-shared-standards.md`. UI must not depend on backend DTOs, and network code must not depend on SwiftUI.

This prevents duplicated models and allows UI previews/mocks to be replaced by real WebSocket and history services without reworking screens.

### Decision 1: Use SwiftUI with focused service objects

Use SwiftUI for all screens and an `ObservableObject` call coordinator for state. Keep network, speech, audio session, history, and speaker verification in separate services so the call state machine can be tested without UI.

The SwiftUI implementation targets iOS 15, so navigation uses `NavigationView` instead of `NavigationStack`, previews use `PreviewProvider` instead of `#Preview`, and custom shapes are used where iOS 16-only shape APIs would otherwise be needed.

Alternatives considered:

- UIKit: mature but slower to build for this visual design and unnecessary for the app scope.
- Hybrid WebView: easier to reuse HTML references but does not satisfy the native Swift delivery expectation.

### Decision 2: Use Azure Speech SDK for STT and TTS, not backend voice mode

The provided chat API has `voice_mode` and `voice_text` fields, but the documented sample returns display-only text and no Azure Speech credentials. Client-side Azure Speech gives direct control over recognition, synthesis, playback cancellation, and interruption.

Alternatives considered:

- Server-generated voice: less client complexity but not documented and would make barge-in cancellation harder.
- Apple Speech/AVSpeechSynthesizer: simpler credentials but conflicts with the explicit Microsoft Azure Speech requirement.

### Decision 3: Use `AVAudioSession` play-and-record with voice processing

Configure `AVAudioSession` as `.playAndRecord` with `.voiceChat` mode and speaker/Bluetooth options. This provides the platform path for echo cancellation, automatic gain control, and voice processing during simultaneous playback and capture.

Azure STT must receive audio from an app-owned microphone pipeline instead of `SPXAudioConfiguration()` default microphone capture. The app captures microphone frames with `AVAudioEngine`, enables voice processing on the input node where supported, converts the result to 16 kHz / 16-bit / mono PCM, and feeds Azure through `SPXPushAudioInputStream`. This gives the app an audio-level control point for echo suppression, VAD, buffering, and future speaker/timbre filtering before cloud recognition.

Alternatives considered:

- Separate playback and recording sessions: simpler but worse for echo cancellation and barge-in.
- Azure SDK default microphone: simpler but prevents app-level processing before STT and leaves speaker echo mitigation mostly outside the app's control.
- Raw audio capture only: more control but requires a custom DSP pipeline.

### Decision 4: Drive conversation with an explicit call state machine

Represent states such as `idle`, `listening`, `recognizing`, `thinking`, `speaking`, `interrupted`, `muted`, `ended`, and `error`. Barge-in is handled as a transition from `speaking` to `interrupted`, then `recognizing`, then `thinking`.

This avoids hidden coupling between UI button state, Azure callbacks, WebSocket events, and TTS playback.

### Decision 5: Segment streaming AI text for TTS by sentence

The WebSocket client appends `final_token.step_output.display_text` to the visible AI transcript immediately. A sentence segmenter buffers tokens and sends completed sentence chunks to TTS, while final completion flushes any remaining text.

This lowers perceived latency compared with waiting for the full final result and avoids speaking unstable partial fragments.

### Decision 6: Treat speaker filtering as layered confidence, not a hard promise

Use three layers: iOS voice processing, local VAD/noise gate, and optional Azure Speaker Recognition verification after enrollment. Very short barge-in utterances may not be long enough for reliable speaker verification, so the implementation shall block chat submission on failed verification when sufficient audio exists, and otherwise show a low-confidence state instead of claiming certainty.

## Risks / Trade-offs

- Azure Speech credentials are absent from the workspace -> provide config placeholders and a visible settings error until key/region are supplied.
- Echo from AI playback may be detected as user speech -> use `.voiceChat`, VAD thresholds, playback ducking/cancellation markers, and true-device tuning.
- WebSocket token stream includes mixed `display_text` and `text` fragments -> parser must prefer `display_text` for user-visible speech and only parse final JSON when complete.
- Speaker verification may reject valid users in noisy conditions -> make it configurable and preserve a clear UI reason when blocked.
- Simulator cannot validate audio behavior -> require true-device QA for STT, TTS, interruption, and speaker filtering.
- Direct HTTP/WebSocket endpoints are non-TLS in the supplied docs -> document transport risk and allow configuration for secure endpoints if the backend later provides them.

## Migration Plan

1. Initialize the iOS project and local configuration files without committing secrets.
2. Implement UI and mock call states first.
3. Connect the chat WebSocket with typed request/response parsing.
4. Add Azure STT and TTS services.
5. Integrate interruption and audio filtering.
6. Add history pages.
7. Validate on physical devices and tune thresholds.

Rollback is simple during development: disable Azure-backed voice services and keep the text/WebSocket path available for debugging.

## Open Questions

- What Azure Speech `subscription key`, `region`, and preferred Chinese voice should be used?
- Should speaker verification be mandatory before every chat submission, or optional with warnings?
- Should the app use fixed `test01` / `35` credentials or expose them in Settings for QA?
