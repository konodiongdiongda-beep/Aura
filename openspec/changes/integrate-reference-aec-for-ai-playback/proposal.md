## Why

Playback-time policy and recognizer resets reduce assistant self-input after the fact, but the microphone can still physically capture the assistant speaker. The stronger fix is to remove assistant playback audio before speech recognition sees the microphone stream.

## What Changes

- Vendor the open-source `aec-rs`/SpeexDSP iOS library for device builds.
- Add an app-level acoustic echo canceller abstraction.
- Feed synthesized assistant playback PCM into an echo-reference buffer.
- Process microphone PCM with the echo reference before pushing audio to Azure recognition.
- Keep simulator builds testable with a Swift fallback canceller because the upstream release ships an iOS device ARM64 library.

## Capabilities

### New Capabilities
- `reference-aec-for-ai-playback`: Use assistant playback audio as far-end reference to reduce assistant self-capture before recognition.

### Modified Capabilities
- Azure speech input stream, controlled TTS playback, and speech service assembly.

## Impact

- Affected code: `AuraVoiceAssistant/Services/Speech`, project build settings, App tests.
- Adds vendored open-source `aec-rs` headers and iOS ARM64 library.
- Simulator remains runnable through a fallback canceller; real device builds can use the vendored AEC library.
