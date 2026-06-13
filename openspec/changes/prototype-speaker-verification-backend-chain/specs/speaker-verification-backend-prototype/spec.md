## ADDED Requirements

### Requirement: Offline user voice enrollment
The system SHALL build an offline current-user voice profile from local WAV recordings without committing private audio artifacts to source control.

#### Scenario: Enrollment samples are available
- **WHEN** the enrollment command receives multiple WAV files for the same user
- **THEN** it SHALL create a profile containing an embedding centroid and extractor metadata

### Requirement: Candidate voice scoring
The system SHALL score candidate WAV input against the enrolled current-user profile.

#### Scenario: Candidate matches enrolled user
- **WHEN** a candidate sample is acoustically close to the enrolled profile
- **THEN** the verifier SHALL return `accepted_current_user` with a similarity score

#### Scenario: Candidate does not match enrolled user
- **WHEN** a candidate sample is acoustically far from the enrolled profile
- **THEN** the verifier SHALL return `rejected_non_user` with a similarity score

#### Scenario: Candidate is ambiguous
- **WHEN** a candidate score is near the configured threshold
- **THEN** the verifier SHALL return `uncertain` rather than claiming a verified user

### Requirement: AI playback simulation
The system SHALL generate and test AI playback and mixed user+AI audio as candidate inputs.

#### Scenario: AI playback is scored
- **WHEN** generated AI speech is scored against the enrolled user profile
- **THEN** the report SHALL show whether it would be rejected before chat submission

#### Scenario: User and AI playback are mixed
- **WHEN** current-user audio is mixed with generated AI playback
- **THEN** the report SHALL include the mix ratio, similarity score, and decision
