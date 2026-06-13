## ADDED Requirements

### Requirement: Profile-backed submission evidence
The system SHALL support attaching speaker verification evidence to a user-turn submission candidate before it is submitted to chat.

#### Scenario: Candidate has verified current-user evidence
- **WHEN** a final recognition candidate includes audio evidence that matches the enrolled current-user profile above the active threshold
- **THEN** the candidate SHALL be eligible for chat submission

#### Scenario: Candidate lacks required evidence
- **WHEN** a final recognition candidate cannot be verified against the current-user profile
- **THEN** the candidate SHALL NOT be submitted while strict speaker isolation is active

### Requirement: AI playback rejection
The system SHALL reject assistant playback captured by the microphone before it reaches chat.

#### Scenario: AI playback alone
- **WHEN** the assistant is playing audio and the microphone captures speech that does not verify as the current user
- **THEN** no user message SHALL be created and no chat request SHALL be sent

#### Scenario: AI playback mixed with current user
- **WHEN** the assistant is playing audio and the microphone captures mixed audio that verifies as the current user above the playback threshold and margin
- **THEN** the current-user candidate SHALL remain eligible for submission

### Requirement: Bystander rejection
The system SHALL reject non-current-user speech even when assistant playback is not active.

#### Scenario: Other speaker during listening
- **WHEN** the app is listening and a bystander speaks without matching the enrolled current-user profile
- **THEN** no user message SHALL be created and no chat request SHALL be sent

### Requirement: Replay verification reports
The system SHALL provide deterministic audio replay reports for speaker isolation scenarios.

#### Scenario: Replay report covers required cases
- **WHEN** the replay verifier runs against recorded user, AI playback, other speaker surrogate, and mixed-audio fixtures
- **THEN** the report SHALL mark only verified current-user cases as submittable

#### Scenario: Uncertain decision is not submittable
- **WHEN** the verifier returns uncertain in strict isolation mode
- **THEN** the report SHALL set `should_submit` to false
