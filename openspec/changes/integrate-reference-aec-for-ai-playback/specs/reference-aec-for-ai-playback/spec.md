## ADDED Requirements

### Requirement: Assistant playback audio is used as AEC reference
The app SHALL feed synthesized assistant playback audio into an echo-reference buffer before or while the audio is played.

#### Scenario: TTS audio data is available
- **WHEN** the controlled synthesizer receives non-empty TTS audio data
- **THEN** it SHALL decode that audio into 16 kHz mono PCM reference data
- **AND** append the reference data to the shared echo-reference buffer

### Requirement: Microphone PCM is echo-cancelled before Azure recognition
The app SHALL process microphone PCM with the shared AEC component before writing audio to Azure.

#### Scenario: Echo reference data exists
- **WHEN** microphone PCM is converted to 16 kHz mono int16
- **THEN** the app SHALL process the PCM through the acoustic echo canceller
- **AND** write the processed PCM to Azure and rolling evidence

#### Scenario: No echo reference data exists
- **WHEN** microphone PCM is converted and no assistant reference is available
- **THEN** the app SHALL preserve the microphone PCM path without failing

#### Scenario: Interrupted transcript starts with assistant playback
- **WHEN** the user barges in and the recognizer emits text that starts with assistant playback followed by user speech
- **THEN** the app SHALL strip the assistant playback prefix before submitting the user turn
- **AND** it SHALL reject the result if no meaningful user speech remains

### Requirement: Device AEC uses vendored open-source library
Device builds SHALL be able to use the vendored `aec-rs` SpeexDSP library as the acoustic echo canceller implementation.

#### Scenario: iOS device build
- **WHEN** the app is built for iPhone device
- **THEN** the project SHALL expose the vendored `aec-rs` C API to Swift code

### Requirement: Simulator remains testable
Simulator builds SHALL run without linking the iOS-device-only AEC static library.

#### Scenario: iPhone Simulator build
- **WHEN** the app is tested in Simulator
- **THEN** AEC wiring tests SHALL pass using a fallback implementation
