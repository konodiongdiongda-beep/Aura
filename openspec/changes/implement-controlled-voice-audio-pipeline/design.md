## Context

`VoiceCore` already owns the call coordinator, speech protocols, sentence segmentation, playback queue, echo text filtering, and phase-5 filtering abstractions. The app target owns Azure Speech and AVFoundation implementations. The current path still has three gaps: TTS playback is not an app-owned lifecycle with completion events, microphone activity uses simple level thresholds without a reliable playback reference, and speaker verification is only a mock seam.

## Goals / Non-Goals

**Goals:**

- Make assistant speech auto-play through a controlled queue with observable playback start, finish, and cancellation.
- Prevent the coordinator from returning to `listening` while assistant audio is still queued or playing.
- Provide app-side hooks for playback-aware echo suppression before audio reaches Azure STT.
- Add a real contract for current-user verification while keeping model implementation pluggable.
- Keep shared behavior in `VoiceCore` and AVFoundation/Azure details in `AuraVoiceAssistant`.

**Non-Goals:**

- Add a heavy on-device source-separation model in this change.
- Guarantee all nearby human speakers are rejected in all acoustic conditions.
- Replace Azure Speech or the backend chat protocol.
- Require physical-device-only code paths for simulator development.

## Decisions

- `SpeechPlaybackControlling` will publish playback events. The coordinator will subscribe to those events when a call starts and use them to maintain `speaking` until playback is drained.
- `TTSPlaybackQueue` will emit `.started`, `.finished`, `.cancelled`, and `.drained` events. The tests will define coordinator behavior before implementation.
- App-controlled Azure playback will synthesize audio data with the existing `synthesize(_:)` method and play it through AVFoundation. This gives the app cancellation and completion control and creates a future place to feed far-end audio into AEC.
- Keep iOS voice-processing audio capture as the first AEC layer. If device testing proves it insufficient, a later change can add WebRTC AudioProcessing using the same playback/reference seam.
- Speaker filtering will remain protocol-first: `SpeakerVerifying` receives speech evidence and returns verified, rejected, insufficient-audio, or disabled. This change wires the flow but does not ship a production voiceprint model.

## Risks / Trade-offs

- Azure `synthesize(_:)` may increase first-audio latency compared with direct SDK default-speaker playback. Sentence segmentation keeps segments short to limit latency.
- AVAudioPlayer-based playback is not a full render-reference AEC implementation. It is an intermediate step that gives controlled playback and prepares for stronger AEC.
- Short barge-in utterances may not contain enough audio for speaker verification. The app must report unavailable confidence instead of pretending verification succeeded.
- Simulator audio cannot prove acoustic isolation. Device testing remains required for echo and other-speaker behavior.

## Migration Plan

1. Add failing `VoiceCore` tests for playback events and coordinator state.
2. Extend shared protocols and mocks to support playback events.
3. Implement event-emitting playback queue behavior.
4. Wire coordinator playback-event handling.
5. Add app-side controlled Azure playback implementation using synthesized audio data.
6. Validate with `swift test`, OpenSpec validation, and iOS workspace build/tests.
