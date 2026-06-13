## ADDED Requirements

### Requirement: Loadable speaker profile
The system SHALL save and load a current-user speaker profile for repeated verification runs.

#### Scenario: Profile is saved after enrollment
- **WHEN** enrollment completes
- **THEN** the profile SHALL be serializable to JSON with user id, extractor metadata, and embedding

#### Scenario: Profile is loaded for a later gate run
- **WHEN** the gate command receives a saved profile path
- **THEN** it SHALL score the candidate without re-running enrollment

### Requirement: Playback-mode gate thresholds
The system SHALL support stricter verification behavior while AI playback is active.

#### Scenario: Candidate is uncertain during playback
- **WHEN** candidate similarity is below the playback accept threshold
- **THEN** the gate SHALL NOT mark the candidate as submittable

#### Scenario: Candidate is accepted during playback
- **WHEN** candidate similarity is above the playback accept threshold
- **THEN** the gate SHALL mark the candidate as submittable

### Requirement: Gate report includes submission decision
The system SHALL report whether a candidate would be submitted to chat.

#### Scenario: Gate rejects candidate
- **WHEN** verification returns rejected or uncertain in strict playback mode
- **THEN** the report SHALL set `should_submit` to false

#### Scenario: Gate accepts candidate
- **WHEN** verification returns accepted current user
- **THEN** the report SHALL set `should_submit` to true
