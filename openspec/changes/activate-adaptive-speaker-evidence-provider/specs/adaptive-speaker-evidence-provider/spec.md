## ADDED Requirements

### Requirement: Runtime adaptive evidence provider
The Azure speech runtime SHALL use a non-noop speaker evidence provider by default.

#### Scenario: Azure final has audio evidence
- **WHEN** Azure recognition receives a final event and recent microphone PCM is available
- **THEN** the recognizer SHALL attempt to attach speaker evidence to the final recognition event

### Requirement: Adaptive current-user profile
The adaptive provider SHALL build an in-memory current-user profile from early speech samples.

#### Scenario: Profile is still enrolling
- **WHEN** the provider has fewer than the required enrollment samples
- **THEN** it SHALL return verified current-user evidence for the enrollment sample and update the in-memory profile

#### Scenario: Profile is mature
- **WHEN** the provider has enough enrollment samples
- **THEN** it SHALL score later candidates against the current-user profile

### Requirement: Speaker decision output
The adaptive provider SHALL classify later candidates as verified current user, other speaker, or uncertain.

#### Scenario: Matching current-user sample
- **WHEN** candidate similarity is above the accept threshold
- **THEN** the provider SHALL return verified current-user evidence

#### Scenario: Non-matching speaker sample
- **WHEN** candidate similarity is below the uncertain band
- **THEN** the provider SHALL return other-speaker evidence

#### Scenario: Borderline speaker sample
- **WHEN** candidate similarity is below the accept threshold but inside the uncertain band
- **THEN** the provider SHALL return uncertain evidence
