## ADDED Requirements

### Requirement: Playback audio must not enroll the user profile
The adaptive speaker evidence provider SHALL NOT mark assistant playback-window audio as current-user enrollment.

#### Scenario: Candidate is captured during assistant playback
- **WHEN** a speaker evidence request is made for audio captured while assistant playback is active
- **THEN** the provider SHALL return non-current-user evidence and SHALL NOT update the current-user profile

### Requirement: Unknown energy must not force playback interruption
The coordinator SHALL NOT treat unknown energy-only microphone activity during assistant playback as sufficient to submit a user turn.

#### Scenario: Assistant playback leaks into the microphone
- **WHEN** the assistant is speaking and the recognizer receives unknown voice activity followed by a final recognition of assistant audio
- **THEN** the coordinator SHALL reject the final as playback echo and SHALL NOT send chat

### Requirement: Speaker verification rejection is non-fatal
Speaker verification rejection SHALL keep the voice session active.

#### Scenario: Playback-window final is rejected
- **WHEN** a final recognition event is rejected as assistant echo, other speaker, uncertain speaker, or unverified speaker
- **THEN** the voice call SHALL remain in a non-error state and continue the current listening or playback flow
