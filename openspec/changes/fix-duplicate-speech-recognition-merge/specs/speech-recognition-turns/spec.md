## ADDED Requirements

### Requirement: Recognition revisions do not duplicate user turns
The system SHALL normalize live speech recognition updates so revised partial or final text for the same user turn does not duplicate overlapping words in the transcript or chat payload.

#### Scenario: Revised final overlaps an auto-submitted partial
- **WHEN** a partial recognition result is auto-submitted and a later final recognition result substantially overlaps but revises that partial before the assistant responds
- **THEN** the system records and sends one merged user turn without repeating the overlapping text

#### Scenario: Later partial extends current user turn
- **WHEN** a later partial recognition result extends the auto-submitted text before the assistant responds
- **THEN** the system replaces the prior partial with the extended text instead of appending a duplicate copy

### Requirement: Genuine continuation remains supported
The system SHALL keep additional non-overlapping user speech as a continuation of the current user turn while the assistant has not started responding.

#### Scenario: Non-overlapping continuation arrives while thinking
- **WHEN** the user says an additional phrase that does not overlap the current user turn before the assistant responds
- **THEN** the system appends the phrase to the existing user turn and sends the merged text
