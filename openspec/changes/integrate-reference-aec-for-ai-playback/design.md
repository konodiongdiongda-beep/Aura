## Context

Current capture flow:

`microphone -> AVAudioEngine voice processing -> 16k PCM -> Azure push stream`

Current playback flow:

`Azure TTS data -> AVAudioPlayer speaker`

These two paths are not connected, so the capture path cannot subtract what the app is playing.

## Decision

Introduce a shared reference AEC component:

- `EchoReferenceAudioBus` stores the assistant far-end PCM at 16 kHz mono int16.
- `ControlledAudioSpeechSynthesizer` decodes TTS audio to PCM and appends it to the reference bus before playback starts.
- `ProcessedAzureAudioInputStream` converts microphone input to 16 kHz mono int16, then passes it through an `AcousticEchoCancelling` implementation before writing to Azure.
- On device, use `aec-rs` via C API where available.
- On simulator, use a deterministic Swift fallback so tests and app startup still work without an iOS-device static library.

## Non-Goals

- Do not replace Apple voice processing; AEC is an additional layer.
- Do not add a full speaker diarization model in this change.
- Do not change chat or coordinator policy.

## Risks / Trade-offs

- AEC quality depends on timing alignment between speaker playback and microphone capture.
- Simulator fallback is not equivalent to SpeexDSP quality; it verifies wiring, not production cancellation quality.
- The upstream `aec-rs` release is iOS ARM64 only, so simulator cannot link the same binary unless we later build an XCFramework with simulator slices.
