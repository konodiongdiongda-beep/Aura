## ADDED Requirements

### Requirement: Realtime audio processing uses layered ownership
The system SHALL separate audio route setup, input voice processing, far-end reference processing, microphone evidence buffering, voice activity emission, speaker evidence, and turn submission policy into distinct responsibilities.

#### Scenario: Assistant playback remains enabled during echo control
- **WHEN** the app is in realtime voice-call mode
- **THEN** the audio route SHALL keep assistant playback enabled
- **AND** echo control SHALL rely on platform voice processing, optional far-end reference processing, and policy gates instead of muting the speaker.

#### Scenario: Microphone capture does not own chat policy
- **WHEN** microphone PCM is captured for Azure speech recognition
- **THEN** the capture path SHALL convert and forward audio
- **AND** it MAY emit voice activity and audio evidence
- **BUT** it SHALL NOT decide whether recognition text becomes a chat turn.

### Requirement: Heuristic components are explicitly labeled
The system SHALL distinguish production audio processing from debug or heuristic fallback components in type names, construction, or documentation.

#### Scenario: Debug echo processor is selected
- **WHEN** the platform-specific AEC implementation is unavailable
- **THEN** the fallback processor SHALL be identifiable as a debug/test subtractive echo processor
- **AND** it SHALL NOT be documented as production-grade AEC.

#### Scenario: Speaker evidence is heuristic
- **WHEN** app-side speaker evidence is produced without a trained speaker-recognition model
- **THEN** the provider SHALL be identifiable as heuristic evidence
- **AND** the coordinator SHALL still treat it as policy evidence rather than guaranteed biometric identity.
